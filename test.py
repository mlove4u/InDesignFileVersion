import os
from InDesignFile import InDesignFile

myInDesignFile = InDesignFile()

#
fld = os.path.join(os.path.dirname(os.path.abspath(__file__)), "file_samples")
_list = []
for root, dirs, files in os.walk(fld):
    for f in files:
        f_path = os.path.join(root, f)
        if not f.startswith("."):
            _list.append(f_path)
#
for x in sorted(_list):
    print(myInDesignFile.get_version(x), x)
