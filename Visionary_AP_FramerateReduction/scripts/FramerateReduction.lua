--[[----------------------------------------------------------------------------

  Application Name: Visionary_AP_FramerateReduction
  
  
  Summary:
  Reduce the frame rate and optionally average over the skipped frames
  
  Description:
  This application reduces the number of frames shown, while optionally
  averaging the values of the skipped frames. The behavior of the application
  can be changed by modifying the config_* variables
  
  How to run:
  Start by running the app (F5) or debugging (F7+F10).
  Set a breakpoint on the first row inside the main function to debug step-by-step.
  See the results in the viewer on the DevicePage.
  
    
------------------------------------------------------------------------------]]

--Start of Global Scope---------------------------------------------------------

-- Variables, constants, serves etc. should be declared here.

local configNthFrame = 5            -- Show one frame per n received frames
local configEnableAveraging = true  -- Show image as the average of the last n frames,
                                    -- or show only every nth frame
local configRangeLow = 1000         -- The range of pixel visualizing, in mm. Pixels
local configRangeHigh = 5000        -- outside the range will be either black or white.

local compositeImage = nil          -- Composite image to calculate average image.
local missingDataImage = nil        -- Image to count the number of missing data.
local imagesSinceDisplay = 0        -- Count how many images have been received since the last display.

-- Create a view and a decoration object to enable capping and similar.
local deco = View.ImageDecoration.create()
deco:setRange(configRangeLow, configRangeHigh)

local viewer = View.create("2DViewer")

local camera = Image.Provider.Camera.create()
Image.Provider.Camera.stop(camera)
--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

--@displayImage(image:Image)
local function displayImage(image)
  View.addImage(viewer, image, deco)
  View.present(viewer)
end

--@initStateImages(width:Int, height:Int)
local function initStateImages(width, height)
  compositeImage = Image.create(width, height, "FLOAT32")
  missingDataImage = Image.create(width, height, "FLOAT32")
end

--@displayEveryNthFrame(image:Imagem,sensordata:SensorData)
local function displayEveryNthFrame(image)
  imagesSinceDisplay = imagesSinceDisplay + 1            --count every frame
  if imagesSinceDisplay == configNthFrame then             --check if enough frames have passed
    displayImage(Image.toType(image[1], "FLOAT32"))          --display the frame
    imagesSinceDisplay = 0                                 --reset counter
  end
end

--@displayEveryNthFrameWithAveraging(image:Image,sensordata:SensorData)
local function displayEveryNthFrameWithAveraging(image)
  local depth_image = image[1]
  depth_image:setMissingDataFlag(false)
  
  -- initialize composite and missing image for the first time
  if (compositeImage == nil) or (missingDataImage == nil) then
    initStateImages(Image.getWidth(depth_image), Image.getHeight(depth_image))
  end
  
  compositeImage = Image.add(compositeImage, Image.toType(depth_image, "FLOAT32"))
  
  -- Need to set the 'missing data flag' for the image here to be able
  -- to extract missing parts of the image.
  depth_image:setMissingDataFlag(true)
  missingDataImage = Image.add(missingDataImage, Image.toType(depth_image:getMissingDataImage(0, 1), "FLOAT32"))
    
  imagesSinceDisplay = imagesSinceDisplay + 1
  
  if imagesSinceDisplay == configNthFrame then
    -- The composite image is the sum of all received images. To
    -- convert it back to distance values, divide it by the number of
    -- images used. The missingDataImage contains the number of
    -- non-zero values have been received for each pixel.
    local divided = Image.divide(compositeImage, missingDataImage)
    displayImage(divided)
    initStateImages(Image.getWidth(depth_image), Image.getHeight(depth_image))
    imagesSinceDisplay = 0
  end
end

--@main()
local function main()
  if configEnableAveraging then
    Image.Provider.Camera.register(camera, "OnNewImage", displayEveryNthFrameWithAveraging)
  else
    Image.Provider.Camera.register(camera, "OnNewImage", displayEveryNthFrame)
  end
  Image.Provider.Camera.start(camera)
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register("Engine.OnStarted", main)
