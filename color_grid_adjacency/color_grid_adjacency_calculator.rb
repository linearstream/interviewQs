class GridItem
  attr_reader :color, :n, :e, :s, :w

  def initialize(color)
    @color=color
    @n = nil
    @e = nil
    @s = nil
    @w = nil
    @visited = false
  end

  def neighbors=(neighbors)
    @n, @e, @s, @w = neighbors
  end

  def neighbors
    return [n, e, s, w]
  end

  def neighbor(direction)
    return send(:"#{direction}")
  end

  def neighbor_color(direction)
    if nb=neighbor(direction)
      nb.color
    end
    return nil
  end

  def visited?
    return @visited ? true : false
  end

  def visit
    @visited=true
  end

  def count_common_neighbors
    visit
    return neighbors.inject(1){ |total, direction|
      if direction && !direction.visited? && direction.color==@color
        total + direction.count_common_neighbors
      else
        total
      end
    }
  end

  def to_s
    return [
      ["?", neighbor_color("n"), "?"],
      [neighbor_color("w"), @color, neighbor_color("e")],
      ["?", neighbor_color("s"), "?"]
    ]
  end

  def inspect
    border = "-"*12
    return "'" + border + "\n" +
      to_s.map{ |row|
        row.join(", ")
      }.join("\n") + "\n" +
      border + "'\n"
  end
end

OrderedPair = Struct.new(:row, :col)

class CoordMgr
  def initialize
    @coordinates = {}
  end

  def generate(ord_pair)
    if !@coordinates.key?(ord_pair)
      @coordinates[ord_pair] = Coord.new(ord_pair, self)
    end
    return @coordinates[ord_pair]
  end
end

class Coord
  def initialize(ord_pair, coord_mgr=nil)
    @ord_pair = ord_pair
    @coord_mgr = coord_mgr
  end

  def row
    return @ord_pair.row
  end

  def col
    return @ord_pair.col
  end

  def north
    return row == 0 ? nil : @coord_mgr.generate(OrderedPair.new(row-1, col))
  end

  def east
    return @coord_mgr.generate(OrderedPair.new(row, col+1))
  end

  def south
    return @coord_mgr.generate(OrderedPair.new(row+1, col))
  end

  def west
    return col == 0 ? nil : @coord_mgr.generate(OrderedPair.new(row, col-1))
  end

  def to_s
    return "(#{row}, #{col})"
  end

  def inspect
    return to_s
  end
end

require 'csv'
class ColorMapLoader
  def self.load(csv_file)
    return CSV.read(csv_file)
  end
end

class ColorMap
  def initialize(color_map_data)
    @data = color_map_data
    @coord_mgr = CoordMgr.new()
  end

  def each
    @data.each_with_index{ |row, row_idx|
      row.each_with_index{ |color, col_idx|
        coord = @coord_mgr.generate(OrderedPair.new(row_idx, col_idx))
        yield coord, color
      }
    }
  end
end

class ColorGrid
  def self.generate(color_map)
    grid = build_color_grid(color_map)
    connect_grid_linkage(grid)
    return new(grid)
  end

  def self.build_color_grid(color_map)
    grid = {}
    color_map.each{ |coord, color|
      grid[coord] = GridItem.new(color)
    }
    return grid
  end

  def self.connect_grid_linkage(grid)
    grid.map{ |coord, grid_item|
      grid_item.neighbors = [
        grid[coord.north],
        grid[coord.east],
        grid[coord.south],
        grid[coord.west]
      ]
    }
  end

  def initialize( grid )
    @grid=grid
  end

  def traverse_shared_colors()
    traversed_results = {}
    @grid.each{ |coords, item|
      if !item.visited?
        traversed_results[coords] = {
          :color => item.color,
          :count => item.count_common_neighbors
        }
      end
    }
    return traversed_results
  end
end

class ColorMapMaxCalculator
  def self.generate(color_map_file)
    # Loads the raw data
    color_map_data = ColorMapLoader.load(color_map_file)
    # ColorMap is stateless and unlinked
    color_map = ColorMap.new(color_map_data)
    # ColorGrid is linked and stateful
    return self.new(ColorGrid.generate(color_map))
  end

  def initialize(color_grid)
    @color_grid = color_grid
  end

  def calculate_shared_max
    return @color_grid.traverse_shared_colors.max_by{ |coord, color_count|
      color_count[:count]
    }
  end

  def report_shared_max(max_data)
    coord, data = max_data
    puts "The max number of adjacent cells with the same color contains the " +
      "cell #{coord}, is color #{data[:color]}, and has size #{data[:count]}"
  end
end

color_map_calc = ColorMapMaxCalculator.generate('colors.csv')
max_data = color_map_calc.calculate_shared_max
color_map_calc.report_shared_max(max_data)
