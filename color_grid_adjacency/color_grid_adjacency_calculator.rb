require 'csv'

# Calculates the color with the maximum number of adjacent cells
class ColorMapMaxAdjacentCalculator
  def self.run(csv_file)
    color_map = ColorMap.generate(csv_file)
    cmmac = generate(color_map)
    ColorMapMaxAdjacentCalculatorReporter.build_report(
      csv_file, color_map, cmmac.calculate_shared_max
    )
  end

  def self.generate(color_map)
    # ColorGrid is linked representation of color_map
    new(ColorGrid.generate(color_map))
  end

  def initialize(color_grid)
    @color_grid = color_grid
  end

  def calculate_shared_max
    @color_grid.traverse_shared_colors.max_by do |_, color_count|
      color_count[:count]
    end
  end
end

# Provides a representation of a 2d array of color strings
# Unlinked representation of input colors
class ColorMap
  def self.generate(csv_file)
    coord_mgr = CoordMgr.new
    color_map_data = ColorMapLoader.load(csv_file)
    new(color_map_data, coord_mgr)
  end

  def initialize(color_map_data, coord_mgr)
    @data = color_map_data
    @coord_mgr = coord_mgr
  end

  def inspect
    @data.map do |line|
      CSV.generate_line(line)
    end
  end

  def flat_map
    @data.each_with_index.flat_map do |row, row_idx|
      row.each_with_index.map do |color, col_idx|
        coord = @coord_mgr.generate(OrderedPair.new(row_idx, col_idx))
        yield coord, color
      end
    end
  end
end

# Manages the coordinates of a color map
class CoordMgr
  def initialize
    @coordinates = {}
  end

  # Returns either the cached coordinate pair or creates a new one and returns
  def generate(ord_pair)
    @coordinates[ord_pair] ||= Coord.new(ord_pair, self)
    @coordinates[ord_pair]
  end
end

# Class for managing an ordered pair and its relation with neighbors
class Coord
  def initialize(ord_pair, coord_mgr)
    @ord_pair = ord_pair
    @coord_mgr = coord_mgr
  end

  def row
    @ord_pair.row
  end

  def col
    @ord_pair.col
  end

  def north
    @coord_mgr.generate(OrderedPair.new(row - 1, col))
  end

  def east
    @coord_mgr.generate(OrderedPair.new(row, col + 1))
  end

  def south
    @coord_mgr.generate(OrderedPair.new(row + 1, col))
  end

  def west
    @coord_mgr.generate(OrderedPair.new(row, col - 1))
  end

  def to_s
    "(#{row}, #{col})"
  end
end

OrderedPair = Struct.new(:row, :col)

# Loads a color map csv file
class ColorMapLoader
  def self.load(csv_file)
    CSV.read(csv_file)
  rescue StandardError => err
    raise err.class, "Failed to load csv file #{csv_file}: #{err.message}"
  end
end

# Returns an array of strings for printing a report
class ColorMapMaxAdjacentCalculatorReporter
  def self.build_report(csv_file, color_map, shared_max)
    report_color_map(csv_file, color_map) +
      [report_shared_max(shared_max)]
  end

  def self.report_color_map(csv_file, color_map)
    border_edge = '-' * 3
    border_mid = '-' * csv_file.length
    [border_edge + csv_file + border_edge,
     color_map.inspect,
     border_edge + border_mid + border_edge]
  end

  def self.report_shared_max(max_data)
    coord, data = max_data
    'The max number of adjacent cells with the same color contains the ' \
      "cell #{coord}, is color #{data[:color]}, and has size #{data[:count]}"
  end
end

# Linked mapping of GridItems that represent a ColorMap
class ColorGrid
  def self.generate(color_map)
    grid = build_color_grid(color_map)
    connect_grid_linkage(grid)
    new(grid)
  end

  def self.build_color_grid(color_map)
    Hash[
      color_map.flat_map do |coord, color|
        [coord, GridItem.new(color)]
      end
    ]
  end

  def self.connect_grid_linkage(grid)
    grid.map do |coord, grid_item|
      grid_item.neighbors = [
        grid[coord.north],
        grid[coord.east],
        grid[coord.south],
        grid[coord.west]
      ]
    end
  end

  def initialize(grid)
    @grid = grid
  end

  def traverse_shared_colors
    Hash[
      unvisited_items.map do |coords, item|
        [coords,
         { color: item.color,
           count: item.count_common_neighbors }]
      end
    ]
  end

  def unvisited_items
    @grid.reject do |_coords, item|
      item.visited?
    end
  end
end

# Stores this item's color and links to neighboring GridItems (n,e,s,w)
class GridItem
  attr_reader :color, :n, :e, :s, :w

  def initialize(color)
    @color = color
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
    [n, e, s, w]
  end

  def neighbor(direction)
    send(direction)
  end

  def neighbor_color(direction)
    neighbor(direction).color
  end

  def visited?
    @visited
  end

  def visit
    @visited = true
  end

  def count_common_neighbors
    # visit ourselves
    visit
    # count ourselves (1)
    neighbors.inject(1) do |total, neighbor|
      if neighbor && neighbor.count?(@color)
        total + neighbor.count_common_neighbors
      else
        total
      end
    end
  end

  def count?(color)
    !visited? && color == @color
  end

  def to_s
    inspect.map { |line| CSV.generate_line(line) }.join("\n")
  end

  # Gives fog-of-war view for current object. Helpful for debugging
  def inspect
    [['?',                neighbor_color(:n), '?'],
     [neighbor_color(:w), @color,             neighbor_color(:e)],
     ['?',                neighbor_color(:s), '?']]
  end
end

# Load the file and calculate the max color max adjacent color
puts ColorMapMaxAdjacentCalculator.run('colors.csv')
