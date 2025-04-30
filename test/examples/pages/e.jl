module E

# https://discourse.julialang.org/t/is-compat-jl-worth-it-for-the-public-keyword/119041/
macro public_or_export(ex)
    args = ex isa Symbol ? (ex,) : Base.isexpr(ex, :tuple) ? ex.args : error()
    return if Base.isdefined(Base, :ispublic)
        esc(Expr(:public, args...))
    else
        esc(Expr(:export, args...))
    end
end

export f_1, f_2
@public_or_export f_3

"f_1"
f_1(x) = x

"f_2"
f_2(x) = x

"f_3"
f_3(x) = x


"g_1"
g_1(x) = x

"g_2"
g_2(x) = x

"g_3"
g_3(x) = x

export T_1

"T_1"
mutable struct T_1 end

"T_2"
mutable struct T_2 end

"T_3"
struct T_3{T} end

end
