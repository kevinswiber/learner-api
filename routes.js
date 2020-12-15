var xml = require("xml");

//DEMO API - you can find a Postman collection for this in the Postman app - in Templates search "learn" and find API Learner

var routes = function(app) {
  //
  // This route processes GET requests, by using the `get()` method in express, and we're looking for them on
  // the root of the application (in this case that's https://rest-api.glitch.me/), since we've
  // specified `"/"`.  For any GET request received at "/", we're sending some HTML back and logging the
  // request to the console. The HTML you see in the browser is what `res.send()` is sending back.
  //
  app.get("/", function(req, res) {
    res.send(
      "<h1>REST API</h1><p>Oh, hi! There's not much to see here - <a href='https://glitch.com/edit/#!/postman-api-learner'>view the code instead</a>" +
        '<script src="https://button.glitch.me/button.js" data-style="glitch"></script><div class="glitchButton" style="position:fixed;top:20px;right:20px;"></div>'
    );
    console.log(process.env.PROJECT_REMIX_CHAIN);
  });

  //get request
  app.get("/info", function(req, res) {
    let responseData = new Object();
    responseData["message"] = "You made a GET request!";
    return res.send(responseData);
  });

  //post request
  app.post("/info", function(req, res) {
    let responseData = new Object();
    responseData["message"] =
      "You made a POST request with the following data!";
    responseData["data"] = req.body;
    return res.send(responseData);
  });

  //put request
  app.put("/info", function(req, res) {
    let responseData = new Object();
    responseData["message"] =
      "You made a PUT request to update id=" +
      req.query.id +
      " with the following data!";
    responseData["data"] = req.body;
    return res.send(responseData);
  });

  //delete request with query parameter
  app.delete("/info", function(req, res) {
    let responseData = new Object();
    responseData["message"] =
      "You made a DELETE request to delete id=" + req.query.id + "!";
    return res.send(responseData);
  });
};

module.exports = routes;
