# Unused Dependency Search

This script allows for the use of C/C++ dependnecy file information (generated with GCC/Clang with the `-MD` option), and to determine which files in the target directories weren't used during compilation.

> Usage: unused_dependencies.sh [OPTION]
>
> Using compiler-generated dependency files (.d), search through target
> directories and list desired file types that aren't used.
> Such files can be generated via GCC/clang with the '-MD' option.
>
>  -f, --filter    Adds the given regex to filter desired files
>  -s, --source    DirectorSource directory that is searched for .d files
>  -t, --target    A target directory of where desired headers being checked for
>  -v, --verbose   Outputs more detailed information
>  -h, --help      Displays this help blurb
>
> Multiple of each option can be applied to use more filters or directories.
> 
> Example: To only check h/hpp files, in the directory /usr/include, with
>          dependency data from /home/build
>
>  unused_dependencies.sh -f \"\.h$\" -f \"\.hpp$\" -s /home/build -t /usr/include