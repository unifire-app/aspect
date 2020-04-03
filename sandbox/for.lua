local data = {
    a = 11,
    b = 22,
    c = 33,
    d = 44,
    e = 55,
    f = 66,
}
do
    print ("Using FOR")
    for k, v in pairs(data) do
        print("key ", k, " has value ", v)
    end
end

do
    print ("Using WHILE")
    local iter, ctx, k, v = pairs(data)
    k,v = iter(ctx, k)
    local prev, next_k, next = nil, iter(ctx, k)
    while k do
        print("key ", k, " has value ", v, " prev value is ", prev, " next value is ", next, " next key is",next_k)
        prev = v
        k,v = next_k, next
        while next_k ~= nil do
            next_k, next  = iter(ctx, next_k)
            --print("repeat", next_k, next)
            if next_k ~= nil and next > 40 then
                break
            end
        end
    end
end

do
    local i = 0
    print ("Using WHILE2")
    local iter, ctx, k = pairs(data)
    local v, prev, next_k, next
    local filter = function(key)
        local val
        --print("repeat", key, val)

        while true do
            key, val  = iter(ctx, key)
            if key ~= nil then
                return key, val
            end
        end
    end
    k,v = filter(k)
    if k then
        prev, next_k, next = nil, filter(k)
    end

    while k do
        print("key ", k, " has value ", v, " prev value is ", prev, " next value is ", next, " next key is",next_k)
        prev = v
        k,v = next_k, next
        if next_k then
            next_k, next = filter(next_k)
        end
        i = i +1
        if i > 16 then
            print("zaloop")
            break
        end
    end
end
