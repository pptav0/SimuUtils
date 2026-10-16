# Well schematic (body of SimuUtils.plot_well_schem). CairoMakie, MakieThemes
# and LaTeXStrings come from the SimuUtilsMakieExt module that includes this file.

Makie.set_theme!(ggthemr(:fresh))        # runs when the extension loads (as before)


# Helper functions

# Axis label for a UomDefinitions length-unit singleton
_unit_label(::FT) = "ft"
_unit_label(::M)  = "m"

function draw_casing_section!(ax, section::Casing, color, alpha)
    # Section params
    top = section.hanger.value
	bottom = section.depth.value
    right_outer = section.od.value / 2
    left_outer = -right_outer
    right_inner = section.id.value / 2
    left_inner = -right_inner
    label = "$(section.od.value)"

    # Draw outer wall
    rect_outer = [Point2f(left_outer, top), Point2f(right_outer, top),
                  Point2f(right_outer, bottom), Point2f(left_outer, bottom)]
    poly!(ax, rect_outer, color=color, transparency=true, alpha=alpha, label=label)

    # Draw inner wall
    rect_inner = [Point2f(left_inner, top), Point2f(right_inner, top),
                  Point2f(right_inner, bottom), Point2f(left_inner, bottom)]
    poly!(ax, rect_inner, color=:white, transparency=true, alpha=1.0)

    return bottom, (left_inner, left_outer), (right_inner, right_outer)
end

# Wellbore construction

"""
    plot_well_schem(;
		outer_geometry::Vector{Casing},
		inner_geometry::Vector{Casing};
		airgap=nothing, water_depth=nothing,
		units::LengthUnit=m)

Plots a 2D wellbore schematic with outer and inner casings.
"""
function plot_well_schem(
		outer_geometry::Vector{Casing},
		inner_geometry::Vector{Casing};
		airgap=nothing, water_depth=nothing,
		units::LengthUnit=m)

    # Prepare depths
    total_depth = maximum([
    	maximum([g.depth.value for g in inner_geometry if g !== nothing]),
    	maximum([g.depth.value for g in outer_geometry if g !== nothing]) ])
    offshore_offset = if airgap !== nothing && water_depth !== nothing
        airgap + water_depth
    else
    	0.0
    end

    # Set up the figure
    uom = _unit_label(units)
    fig = Figure(; size=(600, 800))
    ax = Axis(
    	fig[1, 1],
     	xlabel="Casing Radius (in)", ylabel="Depth ($uom)",
        yreversed=true)

    # Helper to draw casing as filled rectangles (outer and inner)
    function draw_casing!(geom, color, alpha)
        top, bottom = 0.0, 0.0
        hanger, overlap = 0.0, 0.0
        prev_left_inner = nothing
        prev_right_inner = nothing
        for section in geom
        	# Adjust top position based on hanger
            if !isnothing(section.hanger) && section.hanger.value > hanger
                overlap = bottom - section.hanger.value
            end
            hanger = section.hanger.value

            # Draw casing section
            bottom, left, right = draw_casing_section!(ax, section, color, alpha)

            if prev_left_inner !== nothing && overlap > 0.0
                # Draw connecting line from previous left ID to current left OD
                lines!(ax,
                        [prev_left_inner, left[2]],
                        [top, top - overlap], color=color, alpha=alpha, linewidth=3)
                lines!(ax,
                        [left[2], prev_left_inner],
                        [top, top - overlap], color=color, alpha=alpha, linewidth=3)
            end

            if prev_right_inner !== nothing && overlap > 0.0
                # Draw connecting line from previous right ID to current right OD
                lines!(ax,
                        [prev_right_inner, right[2]],
                        [top, top - overlap], color=color, alpha=alpha, linewidth=3)
                lines!(ax,
                        [right[2], prev_right_inner],
                        [top, top - overlap], color=color, alpha=alpha, linewidth=3)
            end
            prev_left_inner = left[1]
            prev_right_inner = right[1]
            top = bottom
        end
    end

    # Draw outer and inner geometry
    draw_casing!(outer_geometry, :gray, 0.6)
    draw_casing!(inner_geometry, :blue, 0.3)

    # Draw offshore water depth and air gap
    if offshore_offset > 0
        # Water surface to seabed
        lines!(ax, [-20, 20], [airgap, airgap], color=:cyan, linewidth=2)
        lines!(ax, [-20, 20], [airgap + water_depth, airgap + water_depth], color=:navy, linewidth=2)
        text!(ax, "Sea Level", position = (0, airgap - 10), align = (:center, :top))
        text!(ax, "Seabed", position = (0, airgap + water_depth - 10), align = (:center, :top))
    end

    # Auto limits and aspect
    xlims!(ax,
     	-maximum([g.od.value for g in outer_geometry]) * 0.6,
      	 maximum([g.od.value for g in outer_geometry]) * 0.6)
    ylims!(ax, total_depth + offshore_offset, 0)
    axislegend(ax, position = :rb)

    fig
end
