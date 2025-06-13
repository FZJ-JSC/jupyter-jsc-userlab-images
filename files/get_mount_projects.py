import re
import requests
import sys

def get_mount_projects(unity_userinfo_url, access_token):
    try:
        r = requests.get(unity_userinfo_url, headers={"Authorization": "Bearer {access_token}".format(access_token=access_token), "Accept": "application/json"})
        r.raise_for_status()
    except:
        return []
    resp = r.json()
    preferred_username = resp.get("preferred_username", False)
    entitlements = resp.get("entitlements", [])
    res_pattern = re.compile(
        r"^urn:"
        r"(?P<namespace>.+?(?=:res:)):"
        r"res:"
        r"(?P<systempartition>[^:]+):"
        r"(?P<project>[^:]+):"
        r"act:"
        r"(?P<account>[^:]+):"
        r"(?P<accounttype>[^:]+)$"
    )
    projects = []
    for entry in entitlements:
        match = res_pattern.match(entry)
        if match:
            project = match.group("project")
            account = match.group("account")
            system = match.group("systempartition")
            if system == "JUDAC":
                continue
            if account == preferred_username and project not in projects:
                projects.append(project)

    return projects

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(sys.argv)
        print("Usage: python3 get_mount_dirs.py <unity_userinfo_url> <access_token>")
        sys.exit(1)

    userinfo_url = sys.argv[1]
    access_token = sys.argv[2]
    print(",".join(get_mount_projects(userinfo_url, access_token)))