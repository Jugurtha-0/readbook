import 'package:flutter/material.dart';


class MyButton extends StatelessWidget {
  final void Function()? onTap;
  final String text;

  const MyButton({
    super.key,
    required this.onTap,
    required this.text,
    });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
  onTap: onTap ,
  
  child: Container(
    padding: EdgeInsets.all(20),
  decoration : BoxDecoration(
color: Colors.brown,
borderRadius: BorderRadius.circular(12),
  ),
  child: Center(
    child: Text(text,
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
    ),
    ),


  ),

    );
  }
}