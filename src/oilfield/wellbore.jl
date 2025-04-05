# modules
using CairoMakie, MakieThemes;
using LaTeXStrings;

Makie.set_theme!(ggthemr(:fresh))

# functions
include("./casings.jl")

"""
    plot_well_schem(;
		outer_geometry::Vector{Casing},
		inner_geometry::Vector{Casing};
		airgap=nothing, water_depth=nothing,
		units::LengthUnit=M::LengthUnit)

Plots a 2D wellbore schematic with outer and inner casings.
"""
function plot_well_schem(
		outer_geometry::Vector{Casing},
		inner_geometry::Vector{Casing};
		airgap=nothing, water_depth=nothing,
		units::LengthUnit=M::LengthUnit)

    # Prepare depths
    total_depth = maximum([g.depth[1] for g in outer_geometry if g !== nothing])
    offshore_offset = 0.0

    if airgap !== nothing && water_depth !== nothing
        offshore_offset = airgap + water_depth
    end

    # Set up the figure
    fig = Figure(; size=(600, 800))
    ax = Axis(
    	fig[1, 1],
     	xlabel="Casing Radius (in)", ylabel="Depth ($units)",
        yreversed=true)

    # Helper to draw casing as filled rectangles (outer and inner)
    function draw_casing!(geom, color, alpha)
        top = 0.0
        for section in geom
            bottom = section.depth[1]
            label = "$(section.od[1])"
            right = section.od[1] / 2
            left = -right
            rect = [Point2f(left, top), Point2f(right, top),
                    Point2f(right, bottom), Point2f(left, bottom)]
            poly!(ax, rect, color=color, transparency=true, alpha=alpha, label=label)
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
     	-maximum([g.od[1] for g in outer_geometry]) * 0.6,
      	 maximum([g.od[1] for g in outer_geometry]) * 0.6)
    ylims!(ax, total_depth + offshore_offset, 0)
    axislegend(ax, position = :rb)

    fig
end
