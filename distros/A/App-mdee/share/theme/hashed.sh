# Hashed theme - append closing hashes to h3-h6
for _mode in light dark; do
    declare -n _theme="theme_${_mode}"
    _theme[h3]+=';sub{s/(?<!#)$/ ###/r}'
    _theme[h4]+=';sub{s/(?<!#)$/ ####/r}'
    _theme[h5]+=';sub{s/(?<!#)$/ #####/r}'
    _theme[h6]+=';sub{s/(?<!#)$/ ######/r}'
done
