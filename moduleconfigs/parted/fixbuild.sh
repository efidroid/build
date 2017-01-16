PostLink() {
    # this disables -rdynamic
    link2file "$MODULE_OUT/configure.ac"
    sed -i 's/backtrace/disabled_backtrace/g' "$MODULE_OUT/configure.ac"
}
