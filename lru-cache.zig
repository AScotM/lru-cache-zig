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
        if (capacity == 0) return error.InvalidCapacity;
        
        const h = try allocator.create(Node);
        errdefer allocator.destroy(h);
        h.* = .{ .key = 0, .value = 0, .prev = null, .next = null };
        
        const t = try allocator.create(Node);
        errdefer {
            allocator.destroy(h);
            allocator.destroy(t);
        }
        t.* = .{ .key = 0, .value = 0, .prev = null, .next = null };
        
        h.next = t;
        t.prev = h;
        
        const map = std.AutoHashMap(i32, *Node).init(allocator);
        
        return LRUCache{
            .capacity = capacity,
            .cache = map,
            .head = h,
            .tail = t,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LRUCache) void {
        // Iterate through cache entries and destroy nodes
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            // In Zig 0.15.x, entry has .key_ptr and .value_ptr
            self.allocator.destroy(entry.value_ptr.*);
        }
        
        self.allocator.destroy(self.head);
        self.allocator.destroy(self.tail);
        self.cache.deinit();
    }

    fn removeNode(node: *Node) void {
        node.prev.?.next = node.next;
        node.next.?.prev = node.prev;
        
        node.prev = null;
        node.next = null;
    }

    fn addToHead(self: *LRUCache, node: *Node) void {
        node.next = self.head.next;
        node.prev = self.head;
        
        self.head.next.?.prev = node;
        self.head.next = node;
    }

    fn moveToHead(self: *LRUCache, node: *Node) void {
        removeNode(node);
        self.addToHead(node);
    }

    fn removeLRU(self: *LRUCache) void {
        const lru = self.tail.prev.?;
        
        removeNode(lru);
        _ = self.cache.remove(lru.key);
        self.allocator.destroy(lru);
    }

    pub fn get(self: *LRUCache, key: i32) ?i32 {
        if (self.cache.get(key)) |node| {
            self.moveToHead(node);
            return node.value;
        }
        return null;
    }

    pub fn put(self: *LRUCache, key: i32, value: i32) !void {
        if (self.cache.get(key)) |node| {
            node.value = value;
            self.moveToHead(node);
            return;
        }
        
        // Use .count() for Zig 0.15.x
        if (self.cache.count() >= self.capacity) {
            self.removeLRU();
        }
        
        const new_node = try self.allocator.create(Node);
        errdefer self.allocator.destroy(new_node);
        new_node.* = .{ .key = key, .value = value, .prev = null, .next = null };
        
        try self.cache.put(key, new_node);
        self.addToHead(new_node);
    }

    pub fn debugPrint(self: *LRUCache) void {
        std.debug.print("Cache (capacity={d}, size={d}): ", .{self.capacity, self.cache.count()});
        
        var current = self.head.next;
        while (current != null and current.? != self.tail) {
            const node = current.?;
            std.debug.print("[{d}:{d}] ", .{node.key, node.value});
            current = node.next;
        }
        std.debug.print("\n", .{});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
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
