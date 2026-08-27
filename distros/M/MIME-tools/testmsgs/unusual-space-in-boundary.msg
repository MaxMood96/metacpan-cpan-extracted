From: Test <null@example.com>
To: Test <null@example.com>
Subject: Unusual space in boundary
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=FOO

--FOO
Content-Type: text/plain

Whatever

--FOO
Content-Type: application/octet-stream
Content-Transfer-Encoding: base64
Content-Disposition: attachment; name="wookie.exe"

Z290Y2hhCg==

--FOO=--
