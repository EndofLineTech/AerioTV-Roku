function videoAspectRatio(aspect as string) as float
    if aspect = "4:3" then return 4.0 / 3.0
    if aspect = "16:9" then return 16.0 / 9.0
    if aspect = "21:9" then return 21.0 / 9.0
    return 0.0
end function

function videoGeometry(width as float, height as float, mode as string, aspect as string) as object
    result = {width: width, height: height, scale: [1.0, 1.0], translation: [0.0, 0.0], mode: "fit"}
    ratio = videoAspectRatio(aspect)
    if width <= 0 or height <= 0 or ratio <= 0 then return result
    if mode <> "fill" and mode <> "stretch" then return result
    baseWidth = width
    baseHeight = width / ratio
    if baseHeight > height
        baseHeight = height
        baseWidth = height * ratio
    end if
    sx = width / baseWidth
    sy = height / baseHeight
    if mode = "fill"
        factor = sx
        if sy > factor then factor = sy
        sx = factor
        sy = factor
    end if
    result.width = baseWidth
    result.height = baseHeight
    result.scale = [sx, sy]
    result.translation = [(width - baseWidth * sx) / 2.0, (height - baseHeight * sy) / 2.0]
    result.mode = mode
    return result
end function
