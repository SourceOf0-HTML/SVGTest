const $element = $(".walk>use");
const imagePath = "./destination";
const totalFrames = 260;
const timePerFrame = 24;
var timeWhenLastUpdate;
var timeFromLastUpdate;
var frameNumber = 1;

function getFramePath(i) {
  return imagePath + "/walk_" + "00000".substr(0, 5 - i.toString().length) + i + ".svg";
}

function step(startTime) {
  if (!timeWhenLastUpdate) timeWhenLastUpdate = startTime;
  timeFromLastUpdate = startTime - timeWhenLastUpdate;
  if (timeFromLastUpdate > timePerFrame) {
    $element.attr("xlink:href", "#Frame_" + frameNumber);
    timeWhenLastUpdate = startTime;
    
    if (frameNumber >= totalFrames) {
      frameNumber = 1;
    } else {
      frameNumber = frameNumber + 1;
    }
  }
  
  requestAnimationFrame(step);
}

$(window).on("load", function() {
  requestAnimationFrame(step);
});
