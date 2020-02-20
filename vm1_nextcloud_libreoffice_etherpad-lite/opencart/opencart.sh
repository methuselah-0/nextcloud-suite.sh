#!/bin/bash

mydomain="domainname"
sdomain="subdomain-name"

# Install prerequisites
php*-mysql
php*-gd
php*-curl
php*-mcrypt
php*-zlib

# create directory and download
mkdir /var/www/$mydomain.tld/$sdomain
cd /var/www/$mydomain.tld/$sdomain && git clone https://github.com/opencart/opencart

chmod 0755 or 0777 system/storage/cache/
chmod 0755 or 0777 system/storage/logs/
chmod 0755 or 0777 system/storage/download/
chmod 0755 or 0777 system/storage/upload/
chmod 0755 or 0777 system/storage/modification/
chmod 0755 or 0777 image/
chmod 0755 or 0777 image/cache/
chmod 0755 or 0777 image/catalog/
chmod 0755 or 0777 config.php
chmod 0755 or 0777 admin/config.php

# If 0755 does not work try 0777.

mysql -u root -p
create database opencartdb

# mv nginx.conf $sdomain.conf && mv $sdomain.conf /etc/nginx/sites-available/
# ln -s /etc/nginx/sites-available/$sdomain.conf /etc/nginx/sites-enabled/$sdomain.conf

echo "You can now finish your installation by visiting store.domain.tld or whatever is in your webserver config"
echo "also, possibly remove or change permissions of some install file in the root install folder"


# LDAP 
# https://sysblog.hallonet.se/opencart-admin-ldap-module/
#
# In this file: /opencart_root/admin/controller/common/login.php
# for example: /var/www/selfhosted.xyz/shop/admin/controller/common/login.php
# below: protected function validate() {
# place this php script:
cat <<EOF >

For version 2.0

//-----------------------------------------------------------------
//---------------------- LDAP authentication ----------------------
//-----------------------------------------------------------------

$ldap_host = "10.0.0.2"; //LDAP Server
$ldap_dn = "ou=Users,dc=domain,dc=local"; //DN to look for users in
$ldap_domain = "domain.local"; //LDAP domain
$ldap_group = "AD Group"; //LDAP group user has to be member of

//Connect to LDAP server
$ldap = ldap_connect($ldap_host);

//Verify username and password
if($bind = @ldap_bind($ldap, $this->request->post['username'] . "@" . $ldap_domain, $this->request->post['password'])){
$filter = "(sAMAccountName=" . $this->request->post['username'] . ")";
$attribute = array("memberof", "mail", "givenname", "sn");
$result = ldap_search($ldap, $ldap_dn, $filter, $attribute);
$entries = ldap_get_entries($ldap, $result);
ldap_unbind($ldap);

//Check if user is member of correct group
foreach($entries[0]['memberof'] as $groups){

if(strpos($groups, $ldap_group)){

//Define variables
$username = $this->request->post['username'];
$salt = substr(str_shuffle("0123456789abcdefghijklmnopqrstuvwxyz"), 0, 9); //Generate a new salt
$firstname = utf8_encode($entries['0']['givenname']['0']);
$lastname = utf8_encode($entries['0']['sn']['0']);
$email = $entries['0']['mail']['0'];
$ip = $_SERVER['REMOTE_ADDR'];

//Connect to SQL
$dbconnect = new mysqli(DB_HOSTNAME, DB_USERNAME, DB_PASSWORD, DB_DATABASE);

//If the user already exists in the database
$query = $dbconnect->query("SELECT * FROM oc_user WHERE username = '" . $this->request->post['username'] . "'");
if($query->num_rows >= 1){

//Update information from LDAP
$dbconnect->query("UPDATE oc_user SET firstname = '" . $firstname . "', lastname = '" . $lastname . "', email = '" . $email . "', ip = '" . $ip . "' WHERE username = '" . $username . "'");

//Get the current password (hash)
$password = $dbconnect->query("SELECT * FROM oc_user WHERE username = '" . $username . "'");
$password = $password->fetch_array(MYSQLI_ASSOC);
$password = $password['password'];

//Generate a new password (hash the old one)
//Also update salt just in case (is salt in use?)
$dbconnect->query("UPDATE oc_user SET password = '" . md5($password) . "', salt = '" . $salt . "' WHERE username = '" . $username . "'");

//Since we know the new password unhashed, we can login
$this->user->login($this->request->post['username'], $password);
return true;

//If the user does not exists in the database
} else {

//Generate a password and hash it
$password = md5(substr(str_shuffle("0123456789abcdefghijklmnopqrstuvwxyz"), 0, 40));

//Create the user
$dbconnect->query("INSERT INTO oc_user (user_group_id, username, password, salt, firstname, lastname, email, ip, status) VALUES (1, '" . $username . "', '" . $password . "', '" . $salt . "', '" . $firstname . "', '" . $lastname . "', '" . $email . "', '" . $ip . "', 1)");

//Generate a new password (hash the old one)
$dbconnect->query("UPDATE oc_user SET password = '" . md5($password) . "' WHERE username = '" . $username . "'");

//Since we know the new password unhashed, we can login
$this->user->login($this->request->post['username'], $password);
return true;
}
}
}
} else {

//Login failed
$this->error['warning'] = $this->language->get('error_login');
return false;
}

$dbconnect->close;

//-----------------------------------------------------------------
//-----------------------------------------------------------------



EOF

