#!/bin/bash
# =============================================================================
# inject_flags.sh - CTF Flag Injection Script for DVWA
# =============================================================================
# Called by Packer during the build phase.
# Flags are passed via environment variables defined in Packer variables.
#
# Vulnerabilities targeted:
#   SQLi           -> UPDATE users SET last_name = FLAG WHERE user='pablo'
#   Cmd Injection  -> /var/www/html/dvwa/vulnerabilities/exec/cmd_flag.txt
#   File Upload    -> /var/www/html/dvwa/hackable/uploads/flag.txt
#   XSS Reflected  -> xss_r/source/low.php  (HTML comment)
#   XSS Stored     -> xss_s/source/low.php  (HTML comment) + table guestbook
#   XSS DOM        -> xss_d/source/low.php  (JS comment)
# =============================================================================

set -e

echo "[*] Starting DVWA CTF flag injection..."
echo ""

# -----------------------------------------------------------------------
# PRE-REQUISITE : créer la table users manuellement
# dvwa.sql n'existe PAS dans les versions récentes de DVWA —
# le schéma est généré dynamiquement via setup.php dans le browser.
# On crée directement les tables nécessaires aux flags.
# -----------------------------------------------------------------------
echo "[*] Creating DVWA users table..."
mysql -u root <<SQLEOF
USE dvwa;
CREATE TABLE IF NOT EXISTS users (
  user_id      int(6)       NOT NULL AUTO_INCREMENT,
  first_name   varchar(15)  NOT NULL,
  last_name    varchar(50)  NOT NULL,
  user         varchar(15)  NOT NULL,
  password     varchar(32)  NOT NULL,
  avatar       varchar(70)  DEFAULT NULL,
  last_login   datetime     DEFAULT NULL,
  failed_login int(3)       DEFAULT NULL,
  PRIMARY KEY (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

INSERT IGNORE INTO users (first_name, last_name, user, password, avatar) VALUES
  ('admin',   'admin',   'admin',   '5f4dcc3b5aa765d61d8327deb882cf99', '/hackable/users/admin.jpg'),
  ('Gordon',  'Brown',   'gordonb', 'e99a18c428cb38d5f260853678922e03', '/hackable/users/gordonb.jpg'),
  ('Hack',    'Me',      '1337',    '8d3533d75ae2c3966d7e0d4fcc69216b', '/hackable/users/1337.jpg'),
  ('Pablo',   'Picasso', 'pablo',   '0d107d09f5bbe40cade3de5c71e9e9b7', '/hackable/users/pablo.jpg'),
  ('Bob',     'Smith',   'smithy',  '5f4dcc3b5aa765d61d8327deb882cf99', '/hackable/users/smithy.jpg');
SQLEOF
echo "    -> Table users créée et peuplée"

# -----------------------------------------------------------------------
# SQL INJECTION FLAG
# Modifie la colonne last_name de l'user 'pablo'.
# Payload étudiant : ' OR 1=1-- dans le champ User ID
# -----------------------------------------------------------------------
echo "[+] Injecting SQLi flag..."
mysql -u root -e "USE dvwa; UPDATE users SET last_name='${FLAG_SQLI}' WHERE user='pablo';"
echo "    -> users.last_name (pablo) = ${FLAG_SQLI}"

# -----------------------------------------------------------------------
# COMMAND INJECTION FLAG
# Fichier texte dans le répertoire exec.
# Payload étudiant : ; cat /var/www/html/dvwa/vulnerabilities/exec/cmd_flag.txt
# -----------------------------------------------------------------------
echo "[+] Injecting Command Injection flag..."
mkdir -p /var/www/html/dvwa/vulnerabilities/exec
echo "${FLAG_CMD_INJECTION}" > /var/www/html/dvwa/vulnerabilities/exec/cmd_flag.txt
chmod 644 /var/www/html/dvwa/vulnerabilities/exec/cmd_flag.txt
chown www-data:www-data /var/www/html/dvwa/vulnerabilities/exec/cmd_flag.txt
echo "    -> Written to /var/www/html/dvwa/vulnerabilities/exec/cmd_flag.txt"

# -----------------------------------------------------------------------
# FILE UPLOAD FLAG
# Fichier flag dans le dossier uploads.
# Étudiant : uploader un webshell PHP, lire flag.txt via le shell obtenu.
# -----------------------------------------------------------------------
echo "[+] Injecting File Upload flag..."
mkdir -p /var/www/html/dvwa/hackable/uploads
echo "${FLAG_FILE_UPLOAD}" > /var/www/html/dvwa/hackable/uploads/flag.txt
chmod 644 /var/www/html/dvwa/hackable/uploads/flag.txt
chown www-data:www-data /var/www/html/dvwa/hackable/uploads/flag.txt
echo "    -> Written to /var/www/html/dvwa/hackable/uploads/flag.txt"

# -----------------------------------------------------------------------
# XSS REFLECTED FLAG
# Commentaire HTML caché dans xss_r/source/low.php.
# Étudiant : injecter <script>alert(1)</script> → Ctrl+U inspecter source.
# -----------------------------------------------------------------------
echo "[+] Injecting XSS Reflected flag..."
cat > /var/www/html/dvwa/vulnerabilities/xss_r/source/low.php <<PHPEOF
<?php
header ("X-XSS-Protection: 0");
// Is there any input?
if( array_key_exists( "name", \$_GET ) && \$_GET[ 'name' ] != NULL ) {
    // Feedback for end user
    \$html .= '<pre>Hello ' . \$_GET[ 'name' ] . '</pre>';
    // Flag caché dans le code source
    \$html .= '<!-- ${FLAG_XSS_REFLECTED} -->';
}
?>
PHPEOF
chown www-data:www-data /var/www/html/dvwa/vulnerabilities/xss_r/source/low.php
echo "    -> Patched xss_r/source/low.php"

# -----------------------------------------------------------------------
# XSS STORED FLAG
# Crée la table guestbook + modifie xss_s/source/low.php.
# Le flag est émis en commentaire HTML à chaque affichage des messages.
# Étudiant : poster <script>alert(1)</script> → inspecter le source.
# -----------------------------------------------------------------------
echo "[+] Injecting XSS Stored flag..."
mysql -u root <<SQLEOF
USE dvwa;
CREATE TABLE IF NOT EXISTS guestbook (
  comment_id smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  comment    varchar(300)         NOT NULL,
  name       varchar(100)         NOT NULL,
  PRIMARY KEY (comment_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
SQLEOF

cat > /var/www/html/dvwa/vulnerabilities/xss_s/source/low.php <<PHPEOF
<?php
if( isset( \$_POST[ 'btnSign' ] ) ) {
    \$message = trim( \$_POST[ 'mtxMessage' ] );
    \$name    = trim( \$_POST[ 'txtName' ] );
    \$message = stripslashes( \$message );
    \$message = mysqli_real_escape_string(\$GLOBALS["___mysqli_ston"], \$message);
    \$name    = mysqli_real_escape_string(\$GLOBALS["___mysqli_ston"], \$name);
    \$query   = "INSERT INTO guestbook ( comment, name ) VALUES ( '\$message', '\$name' );";
    \$result  = mysqli_query(\$GLOBALS["___mysqli_ston"], \$query)
                or die('<pre>' . mysqli_error(\$GLOBALS["___mysqli_ston"]) . '</pre>');
}
// Affichage des messages + flag caché
\$query  = "SELECT * FROM guestbook;";
\$result = mysqli_query(\$GLOBALS["___mysqli_ston"], \$query);
while( \$row = mysqli_fetch_assoc(\$result) ) {
    echo "<div>Name: " . \$row['name'] . "</div>";
    echo "<div>Message: " . \$row['comment'] . "</div>";
    echo "<!-- ${FLAG_XSS_STORED} -->";
}
?>
PHPEOF
chown www-data:www-data /var/www/html/dvwa/vulnerabilities/xss_s/source/low.php
echo "    -> Patched xss_s/source/low.php + table guestbook créée"

# -----------------------------------------------------------------------
# XSS DOM FLAG
# Commentaire JS dans xss_d/source/low.php.
# Étudiant : manipuler ?default=<script>... dans l'URL → inspecter le DOM.
# -----------------------------------------------------------------------
echo "[+] Injecting XSS DOM flag..."
cat > /var/www/html/dvwa/vulnerabilities/xss_d/source/low.php <<PHPEOF
<?php
# No protections, anything goes
?>
<script>
var pos = document.URL.indexOf("default=");
if (pos > -1) {
    var lang = document.URL.substring(pos+8);
    document.write("<option value='" + lang + "'>" + lang + "</option>");
    // Flag caché dans le DOM généré
    document.write("<!-- ${FLAG_XSS_DOM} -->");
}
</script>
PHPEOF
chown www-data:www-data /var/www/html/dvwa/vulnerabilities/xss_d/source/low.php
echo "    -> Patched xss_d/source/low.php"

# -----------------------------------------------------------------------
# PERMISSIONS FINALES
# -----------------------------------------------------------------------
echo "[*] Fixing final permissions..."
chown -R www-data:www-data /var/www/html/dvwa
chmod -R 755 /var/www/html/dvwa

# -----------------------------------------------------------------------
# Final summary
# -----------------------------------------------------------------------
echo ""
echo "[*] ================================================"
echo "[*]  All DVWA CTF flags injected successfully!"
echo "[*] ================================================"
echo "[*]  SQLi          -> users.last_name (pablo)"
echo "[*]  CmdInjection  -> /vulnerabilities/exec/cmd_flag.txt"
echo "[*]  FileUpload    -> /hackable/uploads/flag.txt"
echo "[*]  XSS Reflected -> HTML comment in xss_r response"
echo "[*]  XSS Stored    -> HTML comment in xss_s guestbook"
echo "[*]  XSS DOM       -> JS comment in xss_d DOM"
echo "[*] ================================================"
