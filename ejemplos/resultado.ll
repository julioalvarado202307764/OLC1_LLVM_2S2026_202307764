declare void @print_i32(i32)
declare void @print_f64(double)

define i32 @main() {
entry:
  %t1 = mul i32 20, 2
  %t2 = add i32 10, %t1
  call void @print_i32(i32 %t2)
  ret i32 0
}
