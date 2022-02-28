"""
Configure, build, and install a CMake project in one go.
"""

import sys
import argparse
import subprocess
import itertools
import shutil
from os import path, environ


def _get_program_path(prog):  # type: (str) -> str
    "Find a program on the PATH environment variable"
    if path.basename(prog) != prog:
        # Just a filepath
        path.realpath(prog)
    if 'PATHEXT' in environ:
        extensions = environ['PATHEXT'].split(path.pathsep)
    else:
        extensions = ['']

    paths = environ['PATH'].split(path.pathsep)
    pairs = itertools.product(paths, extensions)
    for pathdir, ext in pairs:
        cand = path.join(pathdir, prog + ext)
        if path.isfile(cand):
            return cand

    raise NameError(
        'No executable "{}" found on the environment PATH'.format(prog))


def main(argv):  # type: (list[str]) -> int
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        '--source-dir',
        metavar='<path-to-source>',
        help='Path to the directory containing a CMake project to build',
        required=True)
    parser.add_argument('--build-dir',
                        metavar='<path-to-build-dir>',
                        help='Directory where build results will be written',
                        required=True)
    parser.add_argument('--config',
                        metavar='{Debug,Release,RelWithDebInfo}',
                        help='Specify the build type/config to build',
                        default='RelWithDebInfo')
    parser.add_argument('--set',
                        '-D',
                        metavar='<KEY>=<VALUE>',
                        help='Specify additional CMake settings for the build',
                        action='append',
                        dest='settings',
                        default=[])
    parser.add_argument('--no-build',
                        help='Configure only without running the build',
                        action='store_true')
    parser.add_argument('--clean',
                        help='Run the "clean" target before building',
                        action='store_true')
    parser.add_argument('--target',
                        metavar='<target-name>',
                        help='Specify one or more targets to build',
                        action='append',
                        default=[])
    parser.add_argument('--install',
                        help='Install the project after buiding',
                        action='store_true')
    parser.add_argument('--install-prefix',
                        metavar='<install-prefix-path>',
                        help='Set the install prefix for the project')
    parser.add_argument('--cmake',
                        metavar='<path-to-cmake-exe>',
                        help='Specify a path to a CMake executable to use',
                        default='cmake')
    parser.add_argument('--generator',
                        '-G',
                        metavar='<cmake-generator>',
                        help='Specify the CMake generator to use')
    parser.add_argument('--toolset', '-T', help='Set a CMake toolset')
    parser.add_argument('--platform', '-A', help='Set a CMake platform')
    parser.add_argument('--wipe',
                        help='Delete the build directory if it exists',
                        action='store_true')
    parser.add_argument('--wipe-after',
                        help='Delete the build directory after finishing',
                        action='store_true')
    parser.add_argument('--test',
                        help='Run CTest after building',
                        action='store_true')
    args = parser.parse_args(argv)

    cmake = _get_program_path(args.cmake)

    config_cmd = [cmake]
    for s in args.settings:
        if '=' not in s:
            raise ValueError(
                'Setting "{}" must be of the form <key>=<value>'.format(s))
        config_cmd.append('-D{}'.format(s))

    config_cmd.append('-DCMAKE_EXPORT_COMPILE_COMMANDS=ON')

    if args.install_prefix is not None:
        config_cmd.append('-DCMAKE_INSTALL_PREFIX={}'.format(
            args.install_prefix))
    if args.config:
        config_cmd.append('-DCMAKE_BUILD_TYPE={}'.format(args.config))
    if args.generator:
        config_cmd.append('-G{}'.format(args.generator))
    if args.toolset:
        config_cmd.append('-T{}'.format(args.toolset))
    if args.platform:
        config_cmd.append('-A{}'.format(args.platform))

    config_cmd.append('-H{}'.format(args.source_dir))
    config_cmd.append('-B{}'.format(args.build_dir))

    if args.wipe and path.isdir(args.build_dir):
        shutil.rmtree(args.build_dir)

    subprocess.check_call(config_cmd)

    if args.no_build:
        return 0

    if args.clean:
        subprocess.check_call([
            cmake,
            '--build',
            args.build_dir,
            '--target',
            'clean',
            '--config',
            args.config,
        ])

    build_cmd = [
        cmake,
        '--build',
        args.build_dir,
        '--config',
        args.config,
    ]
    if args.target:
        build_cmd.append('--target')
        build_cmd.extend(args.target)
    subprocess.check_call(build_cmd)

    if args.test:
        cm_bindir = path.dirname(cmake)
        ctest = path.join(cm_bindir, 'ctest' + path.splitext(cmake)[1])
        subprocess.check_call(
            [
                ctest,
                '-C',
                args.config,
                '-j6',
                '--output-on-failure',
            ],
            cwd=args.build_dir,
        )

    if args.install:
        subprocess.check_call([
            cmake,
            '-DCMAKE_INSTALL_CONFIG_NAME={}'.format(args.config),
            '-P',
            path.join(args.build_dir, 'cmake_install.cmake'),
        ])

    if args.wipe_after:
        shutil.rmtree(args.build_dir)

    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
