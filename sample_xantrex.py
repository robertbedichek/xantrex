
# Curl barfs on buggy responses from Xantrex, so we use this ChatGPT5-written Python to do the query "manually"

python3 - <<'PY'
import socket, sys
h='192.168.1.60'; p=80; path='/xml/XW6048%200/rb.xml'
s=socket.create_connection((h,p),3)
s.sendall(f"GET {path} HTTP/1.0\r\nHost: xantrex\r\nConnection: close\r\n\r\n".encode())
data=b''
while True:
    chunk=s.recv(65536)
    if not chunk: break
#    print( chunk)
    data+=chunk
# split headers/body
parts=data.split(b"\r\n\r\n",1)
sys.stdout.buffer.write(parts[1] if len(parts)>1 else data)
PY
