function plotUnavailableTile(axesHandle, titleText, messageText)
%PLOTUNAVAILABLETILE Mark a diagnostic field as unavailable without guessing.

    arguments
        axesHandle (1,1) matlab.graphics.axis.Axes
        titleText (1,1) string
        messageText (1,1) string = "Not stored in the available run record."
    end

    axis(axesHandle, [0, 1, 0, 1]);
    axis(axesHandle, "off");
    title(axesHandle, titleText, "Interpreter", "none");
    text(axesHandle, 0.5, 0.5, messageText, ...
        "HorizontalAlignment", "center", ...
        "VerticalAlignment", "middle", ...
        "Color", [0.35, 0.35, 0.37], ...
        "FontAngle", "italic", ...
        "FontSize", 9, ...
        "Interpreter", "none");
end
