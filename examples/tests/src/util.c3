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