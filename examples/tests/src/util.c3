module c3rl;

fn void test_ivec2_sign() @test
{
    assert(IVec2{-3, -2}.sign() == {-1, -1});
    assert(IVec2{-3, 2}.sign() == {-1, 1});
    assert(IVec2{3, -2}.sign() == {1, -1});
    assert(IVec2{3, 2}.sign() == {1, 1});
    
    assert(IVec2{0, 2}.sign() == {0, 1});
    assert(IVec2{3, 0}.sign() == {1, 0});
    assert(IVec2{0, 0}.sign() == {0, 0});
}

fn void test_ivec2_distance() @test
{
    assert(IVec2{0, 0}.distance(IVec2{0, 0}) == 0);
    assert(IVec2{0, 0}.distance(IVec2{1, 1}) == 2);
    assert(IVec2{0, 0}.distance(IVec2{1, 0}) == 1);
    assert(IVec2{0, 0}.distance(IVec2{0, 1}) == 1);
    assert(IVec2{4, 5}.distance(IVec2{0, 1}) == 8);
    assert(IVec2{-2, 8}.distance(IVec2{1, 2}) == 9);
    assert(IVec2{4, 0}.distance(IVec2{2, 1}) == 3);
}

fn void test_bitboard() @test
{
    BitBoard bb;
    bb.new_init(8, 8);
    defer bb.free();

    assert(!bb.get({0, 0}));
    bb.set({0, 0}, true);
    assert(bb.get({0, 0}));
    assert(!bb.get({1, 0}));
    bb.set({0, 0}, false);
    assert(!bb.get({0, 0}));

    bb.set({4, 4}, true);
    assert(bb.get({4, 4}));
    bb.clear();
    assert(!bb.get({4, 4}));
}

fn void test_bitboard2() @test
{
    BitBoard bb;
    bb.new_init(80, 80);
    defer bb.free();

    assert(!bb.get({70, 0}));
    bb.set({70, 0}, true);
    assert(bb.get({70, 0}));
    assert(!bb.get({71, 0}));
    bb.set({70, 0}, false);
    assert(!bb.get({70, 0}));

    bb.set({74, 74}, true);
    assert(bb.get({74, 74}));
    bb.clear();
    assert(!bb.get({74, 74}));
}