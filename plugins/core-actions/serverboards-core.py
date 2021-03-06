#!/usr/bin/python

import sys, os
sys.path.append(os.path.join(os.path.dirname(__file__),'../bindings/python/'))
import serverboards
import requests
import subprocess, re

@serverboards.rpc_method
def ping(ip=None, url=None):
    """
    Performs an ping to the given IP / URL

    It calls the system ping command.
    """
    if ip:
        if re.match(r"^\d+\.\d+\.\d+\.\d+$", ip):
            output = subprocess.check_output(["ping", ip, "-c", "1", "-W", "1"])
            ms = re.findall(r" time=(\d+\.\d+) ms", output)
            if ms:
                return { "ms" : float(ms[0]) }
            return False
        raise Exception("Invalid IP")
    elif url:
        return { "ms": http_get(url)["ms"] }
    raise Exception("Invalid ping type")

@serverboards.rpc_method
def http_get(url=None):
    ret = requests.get(url)
    return {
        #"text": ret.text,
        "code": ret.status_code,
        "ms": ret.elapsed.total_seconds()*1000
    }

@serverboards.rpc_method
def set_tags(service=None, tags=None):
    serverboards.rpc.debug("service %s"%repr(service))
    service_tags = serverboards.rpc.call("service.info", service)["tags"] or []
    orig_tags=service_tags[:]
    for i in tags.replace(",", " ").split(" "):
        if i[0]=='-':
            if i[1:] in service_tags:
                service_tags.remove(i[1:])
        elif not i in service_tags:
            service_tags.append(i)
    if service_tags != orig_tags:
        serverboards.rpc.call("service.update", service, { "tags": service_tags })

def base_url():
    url="http://localhost:8080"
    try:
        url=serverboards.rpc.call("settings.get", "serverboards.core.settings/base")["base_url"]
    except:
        pass
    return url

@serverboards.rpc_method
def send_notification(email, subject, body, service=None):
    extra={}
    if service:
        service_data = serverboards.rpc.call("service.info", service)
        if service_data["serverboards"]:
            serverboard=service_data["serverboards"][0]
            service_data["url"] = "%s/#/serverboard/%s/services"%(base_url(), serverboard)
        extra["service"] = service_data

    serverboards.rpc.call("notifications.notify", email=email, subject=subject, body=body, extra=extra)

serverboards.loop() #debug=sys.stderr)
