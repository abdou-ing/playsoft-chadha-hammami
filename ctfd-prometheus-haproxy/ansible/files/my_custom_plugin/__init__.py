def load(app):
    print("My custom plugin loaded successfully!")

    from flask import Blueprint, jsonify, make_response, request
    from io import BytesIO
    from sqlalchemy import event
    from CTFd.models import Solves, Awards, Challenges, Users, db

    # =====================================================================
    # BLUEPRINT (API + Assets)
    # =====================================================================
    report_bp = Blueprint(
        "report",
        __name__,
        url_prefix="/report",
        static_folder="assets",
        static_url_path="/assets"
    )

    # =====================================================================
    # JSON REPORT
    # =====================================================================
    @report_bp.route("/user/<int:uid>")
    def json_report(uid):
        solves = Solves.query.filter_by(user_id=uid).all()
        awards = Awards.query.filter_by(user_id=uid).all()

        competencies = {}
        for s in solves:
            ch = Challenges.query.get(s.challenge_id)
            category = ch.category if ch else "Unknown"
            competencies[category] = competencies.get(category, 0) + 1

        return jsonify({
            "user_id": uid,
            "solves": [{"challenge_id": s.challenge_id, "time": str(s.date)} for s in solves],
            "awards": [{"name": a.name, "value": a.value, "description": a.description} for a in awards],
            "competencies": competencies
        })

    # =====================================================================
    # PDF REPORT
    # =====================================================================
    @report_bp.route("/user/<int:uid>/pdf")
    def pdf_report(uid):
        user = Users.query.get(uid)
        solves = Solves.query.filter_by(user_id=uid).all()
        awards = Awards.query.filter_by(user_id=uid).all()

        buffer = BytesIO()
        pdf = "%PDF-1.4\n"
        objs = []

        objs.append("1 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj")

        y = 750
        lines = []

        def add(text):
            nonlocal y
            safe = text.replace("(", "[").replace(")", "]")
            lines.append(f"BT /F1 12 Tf 50 {y} Td ({safe}) Tj ET")
            y -= 20

        add(f"User report for: {user.name}")
        add("")
        add("Solves:")
        for s in solves:
            ch = Challenges.query.get(s.challenge_id)
            name = ch.name if ch else s.challenge_id
            add(f"- {name}: {s.date}")

        add("")
        add("Awards:")
        for a in awards:
            add(f"- {a.name}: +{a.value} ({a.description})")

        content = "\n".join(lines)

        objs.append(f"2 0 obj << /Length {len(content)} >> stream\n{content}\nendstream endobj")
        objs.append(
            "3 0 obj << /Type /Page /Parent 4 0 R /MediaBox [0 0 612 792] "
            "/Contents 2 0 R /Resources << /Font << /F1 1 0 R >> >> >> endobj"
        )
        objs.append("4 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj")
        objs.append("5 0 obj << /Type /Catalog /Pages 4 0 R >> endobj")

        xrefs = [len(pdf)]
        for o in objs:
            pdf += o + "\n"
            xrefs.append(len(pdf))

        table = f"xref\n0 {len(objs)+1}\n0000000000 65535 f \n"
        for pos in xrefs[:-1]:
            table += f"{pos:010d} 00000 n \n"

        trailer = f"trailer << /Size {len(objs)+1} /Root 5 0 R >>\nstartxref\n{xrefs[-1]}\n%%EOF"
        pdf += table + trailer

        buffer.write(pdf.encode())
        resp = make_response(buffer.getvalue())
        resp.headers["Content-Type"] = "application/pdf"
        resp.headers["Content-Disposition"] = f"attachment; filename=user_{uid}_report.pdf"
        return resp

    # =====================================================================
    # SPEED BONUS (SQLAlchemy event — stable & no duplication)
    # =====================================================================
    MAX_BONUS_SOLVERS = 5

    @event.listens_for(Solves, "after_insert")
    def give_speed_bonus(mapper, connection, solve):
        try:
            user_id = solve.user_id
            challenge_id = solve.challenge_id

            # Count solvers for this challenge
            solves_count = connection.execute(
                Solves.__table__.select().where(Solves.challenge_id == challenge_id)
            ).rowcount

            if solves_count <= MAX_BONUS_SOLVERS:
                challenge = connection.execute(
                    Challenges.__table__.select().where(Challenges.id == challenge_id)
                ).fetchone()

                # Only give award if not already given
                existing_award = connection.execute(
                    Awards.__table__.select()
                    .where(Awards.user_id == user_id)
                    .where(Awards.name == "Speed Bonus")
                    .where(Awards.description == challenge.name)
                ).fetchone()

                if not existing_award:
                    connection.execute(
                        Awards.__table__.insert().values(
                            user_id=user_id,
                            name="Speed Bonus",
                            value=20,
                            description=challenge.name
                        )
                    )

        except Exception as e:
            print("Speed Bonus error:", e)

    # =====================================================================
    # BONUS STATUS API
    # =====================================================================
    @report_bp.route("/bonus/<int:cid>")
    def bonus(cid):
        count = Solves.query.filter_by(challenge_id=cid).count()
        return jsonify({
            "available": count < MAX_BONUS_SOLVERS,
            "remaining": max(0, MAX_BONUS_SOLVERS - count)
        })

    # =====================================================================
    # JS INJECTION (REAL <script> TAG)
    # =====================================================================
    TAG = '<script src="/report/assets/inject.js?v=10"></script>'

    @app.after_request
    def inject_js(response):
        try:
            if response.status_code == 200 and response.mimetype == "text/html":
                if getattr(response, "direct_passthrough", False):
                    response.direct_passthrough = False

                body = response.get_data(as_text=True)

                # Insert BEFORE </body>
                if "</body>" in body and "inject.js" not in body:
                    body = body.replace("</body>", TAG + "</body>")
                    response.set_data(body)
                    print("My custom plugin: JS inserted")

        except Exception as e:
            print("Inject error:", e)

        return response

    # Register blueprint
    app.register_blueprint(report_bp)
