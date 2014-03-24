
var q = require("q");
var async = require("async");

var task_queue = async.queue(function(task, done) {
    console.log("----- " + task.label);
    var d = q.defer();
    task.code(done, d);
}, 1);

function test(label, code) {
    task_queue.push({label: label, code: code});
}

function finish(done, promise) {
    promise.then(function(r) {
        console.log("Fulfilled: " + r);
        done();
    }, function(e) {
        console.log("Rejected: " + e);
        done();
    });
}

test("done -> die", function(done, d) {
    finish(done, d.promise.finally(function() {
        throw "BOOM!";
    }));
    d.resolve(10);
});

test("fail -> normal", function(done, d) {
    finish(done, d.promise.finally(function() {
        return "FOO";
    }));
    d.reject(20);
});

test("fail -> no_callback", function(done, d) {
    finish(done, d.promise.finally());
    d.reject(20);
});
