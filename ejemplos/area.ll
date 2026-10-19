declare void @print_i32(i32)
declare void @print_f64(double)

define i32 @main() {
entry:
  %t1 = fmul double 10.5, 20.0
  call void @print_f64(double %t1)
  ret i32 0
}
