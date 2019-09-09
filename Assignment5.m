
cd 'iris_images';

iris_1 = imread("iris1.bmp");
iris_2 = imread("iris2.gif");
iris_3 = imread("iris3.jpg");
iris_3 = rgb2gray(iris_3);
iris_4 = imread("iris4.jpg");
iris_4 = rgb2gray(iris_4);
iris_5 = imread("iris5.bmp");
iris_6 = imread("iris6.jpg");

cd '..'

imshow(iris_encoder(iris_3), []);

function [output] = iris_encoder(image)

    original = image;

    %remove the eyelids
    figure
    imshow(image);
    title('Trace the eyelid');

    % get the polygon that attempts to remove the eyelid
    h = drawpolygon();
    bw = createMask(h);
    bw = uint8(bw);

    %multiply by the mask to make the image just the roi
    image = image .* bw;

    %smooth the image
    image = imgaussfilt(image, 5);
    %get the edge map
    edge_image = edge(image, 'canny');

    %find the pupil
    [p_centers, p_radii, ~] = imfindcircles(edge_image, [25 70], 'EdgeThreshold', .2, 'Sensitivity', .85);

    if numel(p_radii) == 0
        [p_centers, p_radii, ~] = imfindcircles(edge_image, [25 70], 'EdgeThreshold', .2, 'Sensitivity', .88);
    end

    %find candidates for the outer iris circle
    [i_centers, i_radii, ~] = imfindcircles(edge_image, [round(p_radii + 15) round((p_radii + 100))], 'EdgeThreshold', .1, 'Sensitivity', .995);

    %find the circle that is most likely to be the outer iris circle
    %assume the circle center with the smallest euclidean distance from the
    %pupil center is the circle we want
    distances = sqrt(sum(bsxfun(@minus, p_centers, i_centers).^2, 2));
    closest_center = i_centers(find(distances==min(distances)),:);
    closest_radii = i_radii(find(distances==min(distances)),:);

    %now that we have the 2 circles we need to isolate the iris
    % get roi circles for the circles from the last step
    pupil = drawcircle('Center', p_centers, 'Radius', p_radii);
    iris = drawcircle('Center', closest_center, 'Radius', closest_radii);

    % covert them to roi masks
    bw_pupil = createMask(pupil);
    bw_iris = createMask(iris);

    %remove the pupil from the iris
    bw_iris = bw_iris - bw_pupil;
    %remove any eyelid intersections
    bw_iris = bw_iris - ~logical(bw);

    %display the image with only the iris displayed
    bw_iris = uint8(bw_iris);
    image = original .* bw_iris;

    %crop the image so that only the iris is in it and the iris center is
    %center of the image
    width = 2 * ceil(closest_radii);

    left_bound = round(closest_center(2)) - ceil(closest_radii);
    right_bound = round(closest_center(2)) + ceil(closest_radii);
    top_bound = round(closest_center(1)) - ceil(closest_radii);
    bottom_bound = round(closest_center(1)) + ceil(closest_radii);

    image = image( left_bound:right_bound, top_bound:bottom_bound);

    %convert the cartesian coordinates to a polar mapping
    step = pi/32; %step size
    theta = 0 : step : 2*pi; %range of theta
    r = p_radii : 1 : closest_radii; %range of r

    output = zeros(numel(r), numel(theta)); 

    for i = 1:numel(r)
       for j = 1:numel(theta)
           %get the centered x and y vals
           x = ceil(r(i) * cos(theta(j))) + ceil(closest_radii);
           y = ceil(r(i) * sin(theta(j)))+ ceil(closest_radii);

           output(i, j) = image(x, y);
       end
    end
end



