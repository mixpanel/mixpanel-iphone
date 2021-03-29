
import argparse
import subprocess


parser = argparse.ArgumentParser(description='Release Mixpanel Objective-C SDK')
parser.add_argument('--old', help='old version number', action="store")
parser.add_argument('--new', help='new version number for the release', action="store")
args = parser.parse_args()

def bump_version():
    replace_version('Mixpanel.podspec', args.old, args.new)
    replace_version('Mixpanel/Mixpanel.m', args.old, args.new)
    subprocess.call('git add Mixpanel.podspec', shell=True)
    subprocess.call('git add Mixpanel/Mixpanel.m', shell=True)
    subprocess.call('git commit -m "Version {}"'.format(args.new), shell=True)
    subprocess.call('git push', shell=True)

def replace_version(file_name, old_version, new_version):
    with open(file_name) as f:
        file_str = f.read()
        assert(old_version in file_str)
        file_str = file_str.replace(old_version, new_version)

    with open(file_name, "w") as f:
        f.write(file_str)

def generate_docs():
    subprocess.call('./scripts/generate_docs.sh', shell=True)
    subprocess.call('git add docs', shell=True)
    subprocess.call('git commit -m "Update docs"', shell=True)
    subprocess.call('git push', shell=True)

def add_tag():
    subprocess.call('git tag -a v{} -m "version {}"'.format(args.new, args.new), shell=True)
    subprocess.call('git push origin --tags', shell=True)

def pushPod():
    subprocess.call('pod trunk push Mixpanel.podspec --allow-warnings', shell=True)

def build_Carthage():
    subprocess.call('./scripts/carthage.sh', shell=True)

def main():
    bump_version()
    generate_docs()
    add_tag()
    pushPod()
    build_Carthage()
    print("Congratulations, done!")

if __name__ == '__main__':
    main()