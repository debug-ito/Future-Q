
var q = require("q");
var async = require("async");

var show_state = function(d, label) {
    var prefix = label ? label + " " : "Result ";
    var content = d.promise.inspect();
    console.log(prefix + "state: " + content.state);
    if(content.state === "fulfilled") {
        console.log(prefix + "value: " + content.value);
    }else if(content.state === "rejected") {
        console.log(prefix + "reason: " + content.reason);
    }

};

var test_queue = async.queue(function(task, done) {
    var label = task.label;
    var code = task.code;
    var d = q.defer();
    console.log("---- " + label);
    code(d, function() {
        show_state(d);
        done();
    });
}, 1);

var test = function(label, code) {
    test_queue.push({label: label, code: code});
};

test("normal", function(d, done) {
    d.resolve("AAA");
    done();
});

test("fulfilled promise", function(d, done) {
    var dd = q.defer();
    dd.resolve("BBB");
    
    dd.promise.then(function() {
        console.log("> given promise state: " + dd.promise.inspect().state);
        d.resolve(dd.promise);
        done();
    });
});

test("rejected promise", function(d, done) {
    var dd = q.defer();
    dd.reject("CCC");
    dd.promise.then(null, function() {
        console.log("> given promise state: " + dd.promise.inspect().state);
        d.resolve(dd.promise);
        done();
    });
});

test("pending fulfilled promise", function(d, done) {
    var dd = q.defer();
    d.resolve(dd.promise);
    show_state(d, "d (dd pending):");
    dd.resolve("DDD");
    show_state(dd, "dd:");
    done();
});

test("pending rejected promise", function(d, done) {
    var dd = q.defer();
    d.resolve(dd.promise);
    show_state(d, "d (dd pending):");
    dd.reject("EEE");
    show_state(dd, "dd:");
    done();
});

test("pending fulfilled, try to reject while pending", function(d, done) {
    var dd = q.defer();
    d.resolve(dd.promise);
    show_state(d, "d (dd pending):");
    d.reject("HOGEHOGE");
    show_state(d, "d (tried to reject):");
    dd.resolve("FFF");
    done();
});



