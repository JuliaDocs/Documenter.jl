@info "Running with startup.jl"
function Base.with_output_color(@nospecialize(f::Function), color::Union{Int, Symbol}, io::IO, args...; bold::Bool = false)
   buf = IOBuffer()
   iscolor = Base.get_have_color()
   try f(IOContext(buf, io), args...)
   finally
       str = String(take!(buf))
       if !iscolor
           print(io, str)
       else
           bold && color === :bold && (color = :nothing)
           enable_ansi  = get(Base.text_colors, color, Base.text_colors[:default]) *
                              (bold ? Base.text_colors[:bold] : "")
           disable_ansi = (bold ? Base.disable_text_style[:bold] : "") *
                              get(Base.disable_text_style, color, Base.text_colors[:default])
           first = true
           for line in split(str, '\n')
               first || print(buf, '\n')
               first = false
               isempty(line) && continue
               print(buf, enable_ansi, line, disable_ansi)
           end
           print(io, String(take!(buf)))
       end
   end
end
