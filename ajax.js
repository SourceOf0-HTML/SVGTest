const $element = $(".walk>use");
const imagePath = "./destination";
const totalFrames = 260;
const timePerFrame = 24;
var timeWhenLastUpdate;
var timeFromLastUpdate;
var frameNumber = 0;

function getFramePath(i) {
  return imagePath + "/walk_" + "000".substr(0, 3 - i.toString().length) + i + ".svg";
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
  count = 0;
  for( i = 0; i <= 10; i++ ) {
    $.ajax({
      type: "get",
      url: getFramePath(i)
    }).done(function(data) {
      var svg = $(data).find("svg");
      $("body").prepend(svg);
      count++;
      if( count == 10 ) requestAnimationFrame(step);
    });
  }
});
