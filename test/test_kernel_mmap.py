import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class TestKernelMmap(unittest.TestCase):
    def test_composite_mapping_metadata(self):
        cc = shutil.which(os.environ.get("CC", "cc"))
        if cc is None:
            self.skipTest("C compiler unavailable")
        source = (Path(__file__).parents[1] / "litepcie/software/kernel/main.c").read_text()
        function = source.split("static int litepcie_mmap(", 1)[1].split(
            "static unsigned int litepcie_poll(", 1)[0]
        function = "static int litepcie_mmap(" + function
        fixture = Path(__file__).with_name("kernel_mmap_mock.c").read_text()
        with tempfile.TemporaryDirectory() as directory:
            c_file = Path(directory) / "mmap.c"
            c_file.write_text(fixture.replace("/* DRIVER_MMAP */", function))
            for version in (0x050F00, 0x060500):
                with self.subTest(kernel_version=hex(version)):
                    executable = Path(directory) / "mmap-test"
                    subprocess.run([cc, "-std=c11", "-Wall", "-Wextra", "-Werror",
                        f"-DLINUX_VERSION_CODE={version}", str(c_file), "-o", str(executable)],
                        check=True, capture_output=True, text=True)
                    result = subprocess.run([str(executable)], capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
