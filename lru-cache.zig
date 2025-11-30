const std = @import("std");

const Node = struct {
    key: i32,
    value: i32,
    prev: ?*Node,
    next: ?*Node,
};

const LRUCache = struct {
    const Self = @This();

    capacity: usize,
    cache: std.AutoHashMap(i32, *Node),
    head: *Node,
    tail: *Node,
    size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
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
        
        return Self{
            .capacity = capacity,
            .cache = map,
            .head = h,
            .tail = t,
            .size = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }
        
        self.allocator.destroy(self.head);
        self.allocator.destroy(self.tail);
        self.cache.deinit();
    }

    fn removeNode(self: *Self, node: *Node) void {
        node.prev.?.next = node.next;
        node.next.?.prev = node.prev;
        
        node.prev = null;
        node.next = null;
        
        self.size -= 1;
    }

    fn addToHead(self: *Self, node: *Node) !void {
        node.next = self.head.next;
        node.prev = self.head;
        
        self.head.next.?.prev = node;
        self.head.next = node;
        
        self.size += 1;
    }

    pub fn get(self: *Self, key: i32) ?i32 {
        if (self.cache.get(key)) |node| {
            self.removeNode(node);
            self.addToHead(node) catch return null;
            return node.value;
        }
        return null;
    }

    pub fn put(self: *Self, key: i32, value: i32) !void {
        if (self.cache.get(key)) |node| {
            node.value = value;
            self.removeNode(node);
            try self.addToHead(node);
            return;
        }
        
        if (self.size >= self.capacity) {
            const lru = self.tail.prev.?;
            self.removeNode(lru);
            _ = self.cache.remove(lru.key);
            self.allocator.destroy(lru);
        }
        
        const new_node = try self.allocator.create(Node);
        errdefer self.allocator.destroy(new_node);
        new_node.* = .{ .key = key, .value = value, .prev = null, .next = null };
        
        try self.addToHead(new_node);
        try self.cache.put(key, new_node);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var cache = try LRUCache.init(allocator, 2);
    defer cache.deinit();

    try cache.put(1, 1);
    std.debug.print("Put(1,1) OK\n", .{});
    try cache.put(2, 2);
    std.debug.print("Put(2,2) OK\n", .{});
    
    if (cache.get(1)) |val| 
        std.debug.print("Get(1): {d}\n", .{val}) 
    else 
        std.debug.print("Get(1): miss\n", .{});
    
    try cache.put(3, 3);
    std.debug.print("Put(3,3) OK (evicts 2)\n", .{});
    
    if (cache.get(2)) |val| 
        std.debug.print("Get(2): {d}\n", .{val}) 
    else 
        std.debug.print("Get(2): miss\n", .{});
    
    try cache.put(4, 4);
    std.debug.print("Put(4,4) OK (evicts 1)\n", .{});
    
    if (cache.get(1)) |val| 
        std.debug.print("Get(1): {d}\n", .{val}) 
    else 
        std.debug.print("Get(1): miss\n", .{});
    
    if (cache.get(3)) |val| 
        std.debug.print("Get(3): {d}\n", .{val}) 
    else 
        std.debug.print("Get(3): miss\n", .{});
    
    if (cache.get(4)) |val| 
        std.debug.print("Get(4): {d}\n", .{val}) 
    else 
        std.debug.print("Get(4): miss\n", .{});
}
