From: Test <null@example.com>
To: Test <null@example.com>
Subject: Double boundary with comment
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary(comment)=X; boundary=XY

--XY
Content-Type: text/plain

Whatever

--XY
Content-Type: application/octet-stream
Content-Transfer-Encoding: base64
Content-Disposition: attachment; name="wookie.exe"

Z290Y2hhCg==

--XY=--
