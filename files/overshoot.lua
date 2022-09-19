dist = math.sqrt((start_x-end_x)^2 + (start_y-end_y)^2)
rest_dist = 30
tension = rest_dist - dist

if dist > rest_dist then
    end_x = end_x + ((end_x - start_x)/dist)*tension*0.1
    end_y = end_y + ((end_y - start_y)/dist)*tension*0.1
end