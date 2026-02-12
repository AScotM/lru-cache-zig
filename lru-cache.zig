const std = @import("std");

const Node = struct {
    key: i32,
    value: i32,
    prev: ?*Node,
    next: ?*Node,
};

const LRUCache = struct {
    capacity: usize,
    cache: std.AutoHashMap(i32, *Node),
    head: *Node,
    tail: *Node,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !LRUCache {
        if (capacity == 0) {
            return error.CapacityZero;
        }
        
        const head = try allocator.create(Node);
        errdefer allocator.destroy(head);
        head.* = .{
            .key = 0,
            .value = 0,
            .prev = null,
            .next = null,
        };
        
        const tail = try allocator.create(Node);
        errdefer {
            allocator.destroy(head);
            allocator.destroy(tail);
        }
        tail.* = .{
            .key = 0,
            .value = 0,
            .prev = null,
            .next = null,
        };
        
        head.next = tail;
        tail.prev = head;
        
        var cache = std.AutoHashMap(i32, *Node).init(allocator);
        errdefer cache.deinit();
        
        return LRUCache{
            .capacity = capacity,
            .cache = cache,
            .head = head,
            .tail = tail,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LRUCache) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }
        
        self.allocator.destroy(self.head);
        self.allocator.destroy(self.tail);
        self.cache.deinit();
    }

    fn removeNode(self: *LRUCache, node: *Node) void {
        _ = self;
        if (node.prev) |prev| {
            prev.next = node.next;
        }
        if (node.next) |next| {
            next.prev = node.prev;
        }
        
        node.prev = null;
        node.next = null;
    }

    fn addToHead(self: *LRUCache, node: *Node) void {
        node.prev = self.head;
        node.next = self.head.next;
        
        if (self.head.next) |next| {
            next.prev = node;
        }
        self.head.next = node;
    }

    fn moveToHead(self: *LRUCache, node: *Node) void {
        self.removeNode(node);
        self.addToHead(node);
    }

    fn removeLRU(self: *LRUCache) void {
        const lru = self.tail.prev orelse return;
        if (lru == self.head) {
            return;
        }
        
        self.removeNode(lru);
        _ = self.cache.remove(lru.key);
        self.allocator.destroy(lru);
    }

    pub fn get(self: *LRUCache, key: i32) ?i32 {
        const entry = self.cache.get(key) orelse return null;
        const node = entry;
        self.moveToHead(node);
        return node.value;
    }

    pub fn put(self: *LRUCache, key: i32, value: i32) !void {
        const entry = self.cache.get(key);
        if (entry) |node| {
            node.value = value;
            self.moveToHead(node);
            return;
        }
        
        if (self.cache.count() >= self.capacity) {
            self.removeLRU();
        }
        
        const new_node = try self.allocator.create(Node);
        errdefer self.allocator.destroy(new_node);
        new_node.* = .{
            .key = key,
            .value = value,
            .prev = null,
            .next = null,
        };
        
        try self.cache.put(key, new_node);
        self.addToHead(new_node);
    }

    pub fn debugPrint(self: *LRUCache) void {
        std.debug.print("Cache (capacity={d}, size={d}): ", .{
            self.capacity, self.cache.count()
        });
        
        var current = self.head.next;
        while (current) |node| {
            if (node == self.tail) break;
            std.debug.print("[{d}:{d}] ", .{node.key, node.value});
            current = node.next;
        }
        std.debug.print("\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            std.debug.print("Memory leak detected\n", .{});
        }
    }
    const allocator = gpa.allocator();
    
    var cache = try LRUCache.init(allocator, 2);
    defer cache.deinit();

    try cache.put(1, 1);
    std.debug.print("Put(1,1) ", .{});
    cache.debugPrint();
    
    try cache.put(2, 2);
    std.debug.print("Put(2,2) ", .{});
    cache.debugPrint();
    
    if (cache.get(1)) |val| {
        std.debug.print("Get(1): {d} ", .{val});
        cache.debugPrint();
    } else {
        std.debug.print("Get(1): miss\n", .{});
    }
    
    try cache.put(3, 3);
    std.debug.print("Put(3,3) ", .{});
    cache.debugPrint();
    
    if (cache.get(2)) |val| {
        std.debug.print("Get(2): {d}\n", .{val});
    } else {
        std.debug.print("Get(2): miss\n", .{});
    }
    
    try cache.put(4, 4);
    std.debug.print("Put(4,4) ", .{});
    cache.debugPrint();
    
    if (cache.get(1)) |val| {
        std.debug.print("Get(1): {d}\n", .{val});
    } else {
        std.debug.print("Get(1): miss\n", .{});
    }
    
    if (cache.get(3)) |val| {
        std.debug.print("Get(3): {d} ", .{val});
        cache.debugPrint();
    } else {
        std.debug.print("Get(3): miss\n", .{});
    }
    
    if (cache.get(4)) |val| {
        std.debug.print("Get(4): {d} ", .{val});
        cache.debugPrint();
    } else {
        std.debug.print("Get(4): miss\n", .{});
    }
}
