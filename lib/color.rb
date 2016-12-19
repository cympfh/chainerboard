# color assignment
class Color
  @colors = ['#ff0000', '#00ff00', '#0000ff', '#dddd00', '#00dddd', '#dd00dd']
  @memo = {}
  @pointer = 0
  def self.get(key)
    return @memo[key] if @memo[key]
    c = @colors[@pointer % @colors.size]
    @memo[key] = c
    @pointer += 1
    c
  end
end
