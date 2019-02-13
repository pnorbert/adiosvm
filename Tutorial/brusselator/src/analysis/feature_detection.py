'''Brusselator Feature Detection'''

import adios2
import numpy as np
from mpi4py import MPI
import pandas as pd
import cv2 as cv
import argparse

############################
### Global Variables #######
############################

thresh_val = 100
min_blob_size = 10

############################

def preprocess(im, thresh_val):
    """Convert image to grayscale and threshold"""

    # Blur features
    blurred = cv.GaussianBlur(im, (5, 5), 0)
        
    # Threshold peaks (dark color feature)
    thresh = cv.threshold(blurred, thresh_val, 255, cv.THRESH_BINARY_INV)[1]
        
    return thresh

def filter_blobs(im, min_blob_size):
    """Remove blobs smaller than the minimum desired size"""

    # Find connected components
    ret, labels = cv.connectedComponents(im)

    mask = np.zeros(im.shape, dtype="uint8")

    # loop over the unique components
    for label in np.unique(labels):

        # if this is the background label, ignore it
        if label == 0:
            continue

        # o/w, construct the label mask and count pixels 
        label_mask = np.zeros(im.shape, dtype="uint8")
        label_mask[labels == label] = 255
        numPixels = cv.countNonZero(label_mask)

        # If component is large add to mask
        if numPixels > min_blob_size:
            mask = cv.add(mask, label_mask)

    return mask

def get_feats(im):

    # Find contours of image
    contours = cv.findContours(im,cv.RETR_TREE,cv.CHAIN_APPROX_SIMPLE)[1]

    # Initialize DataFrame to store features
    df = pd.DataFrame(columns=['contour_area', 'contour_perimeter', 
                               'contour_center_x', 'contour_center_y'])

    # Check all contours
    for i, con in enumerate(contours):

        # Dict to store contour specific information
        contour = {}
        cv.drawContours(im, contours, -1, (255,255,255), 3)

        # Feature measures
        contour['contour_area'] = cv.contourArea(con)
        contour['contour_perimeter'] = cv.arcLength(con,True)
        
        M = cv.moments(con)
        
        contour['contour_center_x'] = int(M['m10']/M['m00'])
        contour['contour_center_y'] = int(M['m01']/M['m00'])

        df = df.append(contour, ignore_index=True)

    return df

def segment(im_array, save_loc):
    copy = im_array.copy()
   
    # Preprocess fusion data
    thresh = preprocess(im_array, thresh_val)
    
    # Filter out small blobs
    filt = filter_blobs(thresh, min_blob_size)

    color = cv.cvtColor(copy, cv.COLOR_GRAY2RGB)

    # Trace features on original image
    contours = cv.findContours(filt, cv.RETR_CCOMP, cv.CHAIN_APPROX_SIMPLE)[1]
    cv.drawContours(color, contours, -1, (0,255,0), 1)
    
    # SET SAVE LOCATIONS
    save_path = "feature"

    # Save modified original image
    color2 = cv.resize(color, (0,0), fx=4, fy=4)
    #cv.imshow('img', color2)
    #cv.waitKey(0)
    cv.imwrite("%s.%05d.png"%(save_path, step), color2)

    return filt

if __name__ == '__main__':

    parser = argparse.ArgumentParser()
    parser.add_argument("--instream", "-i", help="Name of the input stream", required=True)
    args = parser.parse_args()

    # Read the data from this object
    fr = adios2.open(args.instream, "r", MPI.COMM_WORLD, "adios2.xml", "FeatureInput")

    global step
    step = 0
    while (not fr.eof()):
        inpstep = fr.currentstep()
        shape = np.fromstring(fr.available_variables()['norm']['Shape'], dtype=int, sep=',').tolist()
        data = fr.read('norm', [0,0], shape, endl=True)
        data2 = (data-np.amin(data))/(np.amax(data)-np.amin(data))*255

        # Read data from specified file
        im_array = data2.astype(np.uint8)

        # Segment
        save_loc = None
        mask = segment(im_array, save_loc)

        # Get features
        feats_df = get_feats(mask)
        print (feats_df)
        step += 1

    fr.close()
