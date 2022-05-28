install.packages("paws")
library(paws)
usethis::edit_r_environ()
library(purrr)
library(tibble)
library(readr)
install.packages("magick")

library(magick)

Sys.setenv(
  "AWS_ACCESS_KEY_ID" = "AKIASBCXF276YK5Z7QQI",
  "AWS_SECRET_ACCESS_KEY" = "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",
  "AWS_REGION" = "ap-southeast-2")

# Create S3 client
s3 <- s3()

# Let us check if there is an S3 bucket we could use
buckets <- s3$list_buckets()
length(buckets$Buckets)

# Create s3 bucket and specify bucket name
s3$create_bucket(Bucket = "joty-bco7007-bucket",
                  CreateBucketConfiguration = list(
                    LocationConstraint = "ap-southeast-2"
                    ))
buckets <- s3$list_buckets()
buckets <- map_df(buckets[[1]],
                  ~tibble(name = .$Name, creationDate = .$CreationDate))
buckets

# Store name of created bucket in a seperate variable
my_bucket <- buckets$name[buckets$name == "joty-bco7007-bucket"]

#Upload the image downloaded to the created s3 bucket
s3$put_object(Bucket = my_bucket, 
              Body = read_file_raw("mbappe_2022.jpg"), 
              Key = "mbappe_2022.jpg")

# Check to see if out image is in our bucket
bucket_objects <- s3$list_objects(my_bucket) %>%
  .[["Contents"]] %>%
  map_chr("Key")
bucket_objects

# Create a Rekognition client
rekognition <- rekognition()

# Referencing an image in Amazon S3 bucket
resp <- rekognition$detect_text(
  Image = list(
    S3Object = list(
      Bucket = my_bucket,
      Name = bucket_objects
      
    )
  )
)

# Parsing the response
resp %>%
  .[["TextDetections"]] %>%
  keep(~.[["Type"]] == "WORD") %>%
  map_chr("DetectedText")


## Part 2

# Load raw images
thief <- readr::read_file_raw("mbappe_2022.jpg") 
suspects <- readr::read_file_raw("common_suspects.jpeg")

# Send images to the compare faces endpoint
resp <- rekognition$compare_faces(
  SourceImage = list(
    Bytes = thief
  ),
  TargetImage = list(
    Bytes = suspects
  )
)
# Identify the lengths
length(resp$UnmatchedFaces)

# Identify the lengths
length(resp$FaceMatches)

# Compare 2 faces (Unmatched vs. FaceMatch)
# Than display the accuracy of the predicted result against the similarity
resp$FaceMatches[[1]]$Similarity

# Convert raw image into a magick object
suspects <- image_read(suspects)

# Extract face match from the response
match <- resp$FaceMatches[[1]]

# Calculate bounding box properties
width <- match$Face$BoundingBox$Width * image_info(suspects)$width
height <- match$Face$BoundingBox$Height * image_info(suspects)$height
left <- match$Face$BoundingBox$Left * image_info(suspects)$width
top <- match$Face$BoundingBox$Top * image_info(suspects)$height

# Add bounding box to supects image
image <- suspects %>%
  image_draw()
rect(left, top, left + width, top + height, border = "red", lty = "dashed", lwd = 5)
image
