
install(){
    apt-get install samba sambacommon
}

create_Shared_Directory(){
    mkdir -p /home/samba-share/allusers
    chown -R root:users /home/samba-share/allusers/
    chmod -R ug+rwx,o+rx-w /home/samba-share/allusers/
}
configure(){
cat <<EOF >> /etc/samba/smb.conf
[allusers]
comment = All Users
path = /home/samba-share/allusers
valid users = @users
force group = users
create mask = 0660
directory mask = 0771
writable = yes
EOF
# fix bind interface from 127.0.0.0/8 to corect ip AND interface, e.g. enp0s25 instead of eth0
#workgroup, wins support, wins server sections perhaps too
}
add_Samba_User(){
    useradd  samba-user -m -G users
    passwd samba-user
    smbpasswd -a samba-user
}

main(){
#    install
    create_Shared_Directory
    configure
    add_Samba_User
    pdbedit -w -L # list users
    systemctl restart smbd
    #Try locally first, then from another machine on the network which also installed samba client. When prompted, use the password entered when adding the user to Samba.
    #To access my share:
    #$ smbclient //ourmachine/me
    #To access your share:
    #$ smbclient -U you //ourmachine/you
    #To access our shared(!) share:
    #$ smbclient //ourmachine/ourfiles
}
main
