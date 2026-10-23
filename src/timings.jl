function build_timer(enabled::Bool)
    timer = TimerOutputs.TimerOutput()
    enabled || TimerOutputs.disable_timer!(timer)
    return timer
end

function check_timings_detail(detail::Float64)
    0 < detail <= 1 || throw(ArgumentError("timings_detail must be a fraction in (0, 1], got $detail"))
    return detail
end

is_at_block(element) = element isa MarkdownAST.CodeBlock && startswith(element.info, "@")

function block_label(codeblock::MarkdownAST.CodeBlock, page)
    lines = find_block_in_file(codeblock.code, page.source)
    location = lines === nothing ? "" : "L$(lines.first)-$(lines.second) "
    return location * codeblock.info * " " * code_excerpt(codeblock.code)
end

function code_excerpt(code)
    without_hidden = replace(code, r"^.*#\s*hide\s*$"m => "")
    return strip(replace(without_hidden, r"\s+" => " "))
end

const TIMINGS_NUMBER_COLUMNS_WIDTH = 2 + 8 + 7

struct TimingRow
    depth::Int
    label::String
    time_ns::Int64
end

function print_build_timings(io::IO, timer::TimerOutputs.TimerOutput, detail::Real)
    return print_build_timings(io, TimerOutputs.todict(timer), detail)
end

function print_build_timings(io::IO, tree::Dict, detail::Real)
    rows = timing_rows(tree, detail)
    total = sum(row.time_ns for row in rows if row.depth == 0; init = 0)
    labels = [repeat("  ", row.depth) * row.label for row in rows]
    label_width = min(maximum(length, labels; init = 0), max(displaysize(io)[2] - TIMINGS_NUMBER_COLUMNS_WIDTH, 20))
    println(io, "Build timings (slowest blocks shown until the listed rows reach $(round(Int, 100 * detail))% of the total runtime):")
    for (row, label) in zip(rows, labels)
        label = rpad(truncate_label(label, label_width), label_width)
        time = lpad(format_time(row.time_ns), 8)
        percent = lpad(format_percent(row.time_ns, total), 7)
        println(io, "  ", label, time, percent)
    end
    return
end

function timing_rows(tree::Dict, detail::Real)
    stages = sorted_by_time(tree["inner_timers"])
    total = sum(subtree["time_ns"] for (_, subtree) in stages; init = 0)
    accounted_outside_pages = sum(subtree["time_ns"] for (stage, subtree) in stages if stage != "ExpandTemplates"; init = 0)
    block_budget = detail * total - accounted_outside_pages

    rows = TimingRow[]
    for (stage, subtree) in stages
        push!(rows, TimingRow(0, stage, subtree["time_ns"]))
        stage == "ExpandTemplates" && append!(rows, page_rows(subtree["inner_timers"], block_budget))
    end
    return rows
end

function page_rows(pages::Dict, block_budget::Real)
    blocks = [(page, label) => block["time_ns"] for (page, subtree) in pages for (label, block) in subtree["inner_timers"]]
    shown_blocks = Set(first.(slowest_within(blocks, block_budget)))
    shown_pages = Set(page for (page, _) in shown_blocks)

    rows = TimingRow[]
    hidden_pages = Pair{String, Int64}[]
    for (page, subtree) in sorted_by_time(pages)
        if page ∉ shown_pages
            push!(hidden_pages, page => subtree["time_ns"])
            continue
        end
        push!(rows, TimingRow(1, page, subtree["time_ns"]))
        hidden_blocks = Int64[]
        for (label, block) in sorted_by_time(subtree["inner_timers"])
            if (page, label) in shown_blocks
                push!(rows, TimingRow(2, label, block["time_ns"]))
            else
                push!(hidden_blocks, block["time_ns"])
            end
        end
        isempty(hidden_blocks) || push!(rows, TimingRow(2, "$(length(hidden_blocks)) other $(plural("block", length(hidden_blocks)))", sum(hidden_blocks)))
    end
    other = isempty(shown_pages) ? "" : "other "
    isempty(hidden_pages) || push!(rows, TimingRow(1, "$(length(hidden_pages)) $other$(plural("page", length(hidden_pages)))", sum(last, hidden_pages)))
    return rows
end

function slowest_within(items::Vector{<:Pair}, budget::Real)
    sorted = sort(items; by = last, rev = true)
    kept = empty(sorted)
    accumulated = 0
    for item in sorted
        accumulated >= budget && break
        push!(kept, item)
        accumulated += last(item)
    end
    return kept
end

sorted_by_time(timers::Dict) = sort(collect(timers); by = ((_, subtree),) -> subtree["time_ns"], rev = true)

plural(word, n) = n == 1 ? word : word * "s"

function truncate_label(label, width)
    length(label) <= width && return label
    return first(label, width - 1) * "…"
end

function format_time(ns)
    ns >= 1.0e9 && return string(round(ns / 1.0e9; digits = 1), "s")
    ns >= 1.0e6 && return string(round(Int, ns / 1.0e6), "ms")
    return string(round(Int, ns / 1.0e3), "μs")
end

format_percent(part, total) = total == 0 ? "-" : string(round(100 * part / total; digits = 1), "%")
