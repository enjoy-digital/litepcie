import os
from distutils.dir_util import copy_tree

def copy_litepcie_software(dst):
	src = os.path.abspath(os.path.dirname(__file__))
	copy_tree(src, dst)
