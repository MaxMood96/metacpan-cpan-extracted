<TMPL_INCLUDE NAME="mail_header.tpl">

<p>
<span trspan="hello">Hello</span> <TMPL_VAR NAME="session_cn" ESCAPE=HTML>,<br />
<br />
<a href="<TMPL_VAR NAME="url" ESCAPE=HTML>" style="text-decoration:none;color:orange;">
<span trspan="click2Reset">Click here to reset your password</span>
</a>
</p>

<TMPL_INCLUDE NAME="mail_footer.tpl">
