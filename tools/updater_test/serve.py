"""Serves what tools/test_updater.sh put in a folder, and misbehaves on request.

serve.py <folder> <port>. A file named hang says which file to hang on the first
time it is asked for; everything asked for is added to requests.log.
"""
import http.server
import os
import sys
import time

FOLDER, PORT = sys.argv[1], int(sys.argv[2])
hung = set()


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=FOLDER, **kwargs)

    def log_message(self, *args):
        pass

    def do_GET(self):
        name = self.path.strip("/")
        with open(os.path.join(FOLDER, "requests.log"), "a") as log:
            log.write(name + "\n")
        hang = os.path.join(FOLDER, "hang")
        if os.path.exists(hang) and open(hang).read().strip() == name and name not in hung:
            hung.add(name)
            time.sleep(30)
            return
        super().do_GET()


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
