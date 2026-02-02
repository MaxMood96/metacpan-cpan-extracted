# Warm theme - Coral base color
# Light mode: full definition
# Dark mode: differences only (inherits from light)

declare -gA theme_warm_light=(
           [base]='<Coral>=y25'
        [comment]='${base}+r60'
           [bold]='${base}D'
         [strike]='X'
         [italic]='I'
           [link]="$link_func"
          [image]="$image_func"
     [image_link]="$image_link_func"
             [h1]='L25DE/${base}'
             [h2]='L25DE/${base}+y20'
             [h3]='L25DN/${base}+y30'
             [h4]='${base}UD'
             [h5]='${base}+y20;U'
             [h6]='${base}+y20'
    [inline_code]='L15/L23,/L23,L15/L23'
     [code_block]='L20 , L18 , /L23;E , L20'
)

declare -gA theme_warm_dark=(
           [base]='<Coral>=y80'
             [h1]='L00DE/${base}'
             [h2]='L00DE/${base}-y15'
             [h3]='L00DN/${base}-y25'
    [inline_code]='L12/L05,/L05,L12/L05'
     [code_block]='L10 , L12 , /L05;E , L10'
)
