import sys
import time
import argparse
import re
import requests
import random
import string
import json
from requests_toolbelt import MultipartEncoder
from urllib.parse import urlparse


class Routes:
    def __init__(self, route):
        self.route = route

    def get_method(self):
        req_method = self.route.split("  ")[0]
        if req_method == "GET/POST":
            req_method = "POST"
        req_method = req_method.split("/")[0]
        return req_method

    def get_path(self):
        req_path = self.route.split("  ")[1].split("?")[0]
        req_path = req_path.replace("/*/", "/").replace("/*", "/")

        re_finds = re.findall("([a-zA-Z0-9_]+_Param)", req_path)
        for re_find in re_finds:
            # 一般PathVariable只会有string或者int类型
            if re_find.split("_")[1] in ["String", "StringBuilder", "StringBuffer", "StringJoiner"]:
                path_variable = "KeyParam"
                req_path = req_path.replace(re_find, path_variable)
            elif re_find.split("_")[1] in ["BigInteger", "BigDecimal", "Integer"]:
                path_variable = "1"
                req_path = req_path.replace(re_find, path_variable)
            elif re_find.split("_")[1] in ["Date"]:
                path_variable = "2020-11-11"
                req_path = req_path.replace(re_find, path_variable)

        re_finds = re.findall("(;[a-zA-Z0-9_=]+)", req_path)
        for re_find in re_finds:
            chr_index1 = re_find.index("_")
            chr_index2 = re_find.index("=")
            req_path = req_path.replace(re_find, re_find[:chr_index1] + re_find[chr_index2:])

        return req_path

    def get_param(self):
        req_param = self.route.split("  ")[1]
        req_param_dict = {}
        if "?" in req_param:
            req_param = req_param.split("?")[-1]
            for param in req_param.split("&"):
                if param in ["ParamIsRandom_Reader=test", "ParamIsRandom_ByteArrayResource=test", "ParamIsRandom_InputStreamResource=test", "ParamIsRandom_InputStream=test"]:

                    param_name = "NoParam" + ''.join(random.choice(string.ascii_lowercase) for _ in range(5))
                    req_param_dict[param_name] = "testBody"
                elif param in ["ParamIsRandom_MultipartHttpServletRequest=filename.jpg", "ParamIsRandom_Multipart=filename.jpg"]:

                    param_name = "ParamIsRandom_" + ''.join(random.choice(string.ascii_lowercase) for _ in range(5))
                    req_param_dict[param_name] = "filename.jpg"

                elif "_Multipart = filename.jpg" in param:
                    req_param_dict[param[:-25]] = "filename.jpg"
                elif "[" in param:
                    re_match = re.match("([a-z0-9A-Z]+)_[a-zA-Z0-9]+\[([a-zA-Z0-9]+)\]", param)
                    param_name = re_match.group(1)
                    map_key = re_match.group(2)
                    param_value = param.split("=")[-1]
                    req_param_dict[param_name + "[" + map_key + "]"] = param_value
                elif "/" in param:
                    param_name = param.split("=")[0].split("_")[0]
                    param_value = param.split("=")[1].split('/')[0]
                    req_param_dict[param_name] = param_value
                else:
                    param_name = param.split("_")[0]
                    param_value = param.split("=")[-1]
                    req_param_dict[param_name] = param_value

            return req_param_dict
        else:
            return {}

    def get_content_type(self):
        req_content_type = self.route.strip().split("  ")[2]
        return req_content_type.split("&")[0]



def get_target_routes(target, route_file):
    target_routes = []

    # route_list = cc.split("\n")
    # route_list = r.split("\n")
    # route_list = dd.split("\n")

    with open(route_file, "r") as f:
        route_list = f.readlines()


    for route in route_list:
        target_route = {"param": "", "content_type": "", "is_upload": False, "target": target}

        route = route.rstrip(" ")
        routes_class = Routes(route)

        target_route["method"] = routes_class.get_method()
        target_route["path"] = routes_class.get_path()
        target_route["uri"] = target_route["path"]

        if route.find("?") > -1:
            target_route["param"] = routes_class.get_param()
            target_route["uri"] = target_route["path"] + "?" + '&'.join([x + "=" + y for x, y in target_route["param"].items()])

        if "=filename.jpg" in target_route["uri"]:
            target_route["is_upload"] = True

        if route.strip().count("  ") > 1:
            target_route["content_type"] = routes_class.get_content_type()

        # print(target_route["method"] + " " + target_route["uri"] + " " + target_route["content_type"])
        target_routes.append(target_route)

    return target_routes


# TODO: xml格式待处理
def request_target(target_routes, proxy_url):
    for target_route in target_routes:
        target_method = target_route.get("method")
        target = target_route.get("target")
        target_uri = target_route.get("uri")
        target_param = target_route.get("param")
        target_path = target_route.get("path")
        target_content_type = target_route.get("content_type")

        target_param_json = None

        proxies = {}

        if proxy_url:
            proxy_urlparse = urlparse(proxy_url)
            target_host = proxy_urlparse.netloc

            proxies["http"] = "http://" + target_host
            proxies["https"] = "https://" + target_host

        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.84 Safari/537.36"}

        if target_content_type:
            headers["Content-Type"] = target_content_type.lstrip("Content-Type :")

        if target_content_type.rfind("application/json") > -1:
            target_param_json = target_param
            target_param = None

        if target_route.get('is_upload'):

            for x, y in target_param.items():
                if "filename.jpg" == y:
                    target_param[x] = ("filename.jpg", "testtesttest", 'image/png')

            m = MultipartEncoder(fields=target_param)

            resp = requests.post(target + target_path, data=m, headers={'Content-Type': m.content_type}, proxies=proxies)
        elif target_method == "GET":
            resp = requests.get(target + target_uri.replace(" ", "+"), headers=headers, proxies=proxies)
        elif target_method == "POST":
            resp = requests.post(target + target_path, data=target_param, json=target_param_json, headers=headers, proxies=proxies)
        elif target_method == "PUT":
            resp = requests.put(target + target_path, data=json.dumps(target_param), headers=headers, proxies=proxies)


def save_route_info(target_routes):
    target = target_routes[0].get("target")
    target_urlparse = urlparse(target)
    target_host = target_urlparse.netloc

    with open("{}_RoutesSave_{}.txt".format(target_host.replace(":", "_"), int(time.time())), "w+") as f:
        for target_route in target_routes:
            target_method = target_route.get("method")

            target_uri = target_route.get("uri")
            target_path = target_route.get("path")
            target_param = target_route.get("param")
            target_content_type = target_route.get("content_type")

            if target_route.get('is_upload'):
                for x, y in target_param.items():
                    if "filename.jpg" == y:
                        target_param[x] = ("filename.jpg", "testtesttest", 'image/png')

                m = MultipartEncoder(fields=target_param)
                body = m.to_string().decode().replace("\r", "")
                request_string = """{method} {path} HTTP/1.1\nHost: {host}\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.84 Safari/537.36\nAccept-Encoding: gzip, deflate\nAccept: */*\nConnection: close{content_type}\n\n{body}""".format(method=target_method, path=target_path, host=target_host, content_type=m.content_type, body=body)

            elif target_method == "GET":
                if target_content_type != "":
                    target_content_type = "\n" + target_content_type

                request_string = """{method} {path} HTTP/1.1\nHost: {host}\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.84 Safari/537.36\nAccept-Encoding: gzip, deflate\nAccept: */*\nConnection: close{content_type}\n\n""".format(method=target_method, path=target_uri, host=target_host, content_type=target_content_type)

            else:
                # TODO: XML格式，需要转换
                if target_content_type.rfind("application/json") > -1:
                    data = json.dumps(target_param)
                else:
                    data = '&'.join([x + "=" + y for x, y in target_param.items()])

                request_string = """{method} {path} HTTP/1.1\nHost: {host}\nUser-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.84 Safari/537.36\nAccept-Encoding: gzip, deflate\nAccept: */*\nConnection: close\n{content_type}\n\n{body}""".format(method=target_method, path=target_path, host=target_host, content_type=target_content_type, body=data)

            f.write(request_string + "\n" + "="*50 + "\n")


epilog = r'''Example:
python3 SpringMVCMapping.py -r http://sample/ -f route.txt -a 0
python3 SpringMVCMapping.py -r http://sample/ -f route.txt -a 1
python3 SpringMVCMapping.py -r http://sample/ -p http://127.0.0.1:8080  -f route.txt -a 1
'''
parse = argparse.ArgumentParser(epilog=epilog, formatter_class=argparse.RawDescriptionHelpFormatter)
parse.add_argument('-r', '--req', help='输入请求目标地址，默认为http://127.0.0.1', default="http://127.0.0.1")
parse.add_argument('-f', '--file', help='存放路由的文件名，文件需存放在脚本相同目录中')
parse.add_argument('-p', '--proxy', help='输入请求代理地址')
parse.add_argument("-a", "--action", type=int, choices=[0, 1], help="0表示保存文件默认生成在当前目录中，1表示直接发送请求。默认为0", default=0)

args = parse.parse_args()
target = args.req.rstrip("/")
file = args.file
proxy_url = args.proxy
action = args.action

if action == 0:
    target_routes = get_target_routes(target, file)
    save_route_info(target_routes)
elif action == 1:
    target_routes = get_target_routes(target, file)
    request_target(target_routes, proxy_url)
else:
    parse.print_help()
    sys.exit()




