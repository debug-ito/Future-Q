
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
    return promise.then(function(r) {
        console.log("Fulfilled: " + r);
        done();
    }, function(e) {
        console.log("Rejected: " + e);
        done();
    });
}

function print_args(args) {
    var i;
    if(args.length === 0) {
        console.log("No arg");
        return;
    }
    for(i = 0 ; i < args.length ; i++) {
        console.log("arg["+i+"]" + args[i]);
    }
}

function explain(name, promise) {
    return name + " is " + promise.inspect().state;
}

test("done -> normal", function(done, d) {
    finish(done, d.promise.finally(function(hoge) {
        print_args(arguments);
        return "return";
    }));
    d.resolve("orig");
});

test("done -> die", function(done, d) {
    finish(done, d.promise.finally(function() {
        print_args(arguments);
        throw "return!";
    }));
    d.resolve("orig");
});

test("done -> done promise", function(done, d) {
    var dd = q.defer();
    var next = d.promise.finally(function() {
        print_args(arguments);
        console.log("d is done. " + explain("next", next));
        q.delay(100).then(function() {
            console.log("timeout. " + explain("next", next));
            dd.resolve("return");
        });
        return dd.promise;
    });
    finish(done, next);
    d.resolve("orig");
});

test("done -> fail promise", function(done, d) {
    var dd = q.defer();
    var next = d.promise.finally(function() {
        print_args(arguments);
        console.log("d is done. " + explain("next", next));
        q.delay(100).then(function() {
            console.log("timeout. " + explain("next", next));
            dd.reject("return!");
        });
        return dd.promise;
    });
    finish(done, next);
    d.resolve("done");
});

test("done -> no_callback", function(done, d) {
    finish(done, d.promise.finally());
    d.resolve("orig");
});

test("fail -> normal", function(done, d) {
    finish(done, d.promise.finally(function() {
        print_args(arguments);
        return "return";
    }));
    d.reject("orig!");
});

test("fail -> die", function(done, d) {
    finish(done, d.promise.finally(function() {
        print_args(arguments);
        throw "return!";
    }))
    d.reject("orig!");
})

test("fail -> done promise", function(done, d) {
    var dd = q.defer();
    var next = d.promise.finally(function() {
        print_args(arguments);
        console.log("d is failed. " + explain("next", next));
        q.delay(100).then(function() {
            console.log("timeout. " + explain("next", next));
            dd.resolve("return");
        });
        return dd.promise;
    });
    finish(done, next);
    d.reject("orig!");
});

test("fail -> fail promise", function(done, d) {
    var dd = q.defer();
    var next = d.promise.finally(function() {
        print_args(arguments);
        console.log("d is failed. " + explain("next", next));
        q.delay(100).then(function() {
            console.log("timeout. " + explain("next", next));
            dd.reject("return!");
        });
        return dd.promise;
    });
    finish(done, next);
    d.reject("orig!");
});

test("fail -> no_callback", function(done, d) {
    finish(done, d.promise.finally());
    d.reject("orig!");
});

