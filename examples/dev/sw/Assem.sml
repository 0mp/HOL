structure Assem = struct

  type label = Temp.label

  exception invalidAssemExp;

  type address = {reg:int, offset:int, wback:bool};

  datatype operation =  ADD | SUB | RSB | MUL | MLA |
                        AND | ORR | EOR | CMP | TST |
                        LSL | LSR | ASR | ROR |
                        LDR | STR | LDMFD | STMFD | 
			MRS | MSR |
                        B | BL |
                        SWI | DCD |
                        NOP

  datatype alias = FP | IP | SP | LR | PC

  datatype exp = NAME of Temp.label
	       | TEMP of int
	       | NCONST of int
	       | WCONST of int 
	       | PAIR of exp * exp
	       | CALL of exp * exp list
	       | TMEM of int
	       | MEM of address
	       | REG of int
	       | WREG of int
	       | ALIAS of alias
	       | SHIFT of operation * int

  datatype cond = EQ | NE | GE | LE | GT | LT | AL | NV

  datatype instr = OPER of {oper: operation * cond option * bool,
			    dst: exp list,
			    src: exp list,
			    jump: label list option}
                 | LABEL of {lab: label}
                 | MOVE of {dst: exp,
			    src: exp};

  val indent = "        "

  fun pair2list (PAIR(v1, v2)) =
        (pair2list v1) @ (pair2list v2)
   |  pair2list v = [v]

  fun fromAlias FP = 11
   |  fromAlias IP = 12
   |  fromAlias SP = 13
   |  fromAlias LR = 14
   |  fromAlias PC = 15

  fun toAlias 11 = FP
   |  toAlias 12 = IP
   |  toAlias 13 = SP
   |  toAlias 14 = LR
   |  toAlias 15 = PC
   |  toAlias _ = raise invalidAssemExp

  fun print_op ADD = "ADD"
   |  print_op SUB = "SUB"
   |  print_op RSB = "RSB"
   |  print_op MUL = "MUL"
   |  print_op MLA = "MLA"
   |  print_op AND = "AND"
   |  print_op ORR = "ORR"
   |  print_op EOR = "XOR"
   |  print_op CMP = "CMP"
   |  print_op TST = "TST"
   |  print_op LSL = "LSL"
   |  print_op LSR = "LSR"
   |  print_op ASR = "ASR"
   |  print_op ROR = "ROR"
   |  print_op LDR = "LDR"
   |  print_op LDMFD = "LDMFD"
   |  print_op STR = "STR"
   |  print_op STMFD = "STMFD"
   |  print_op MRS = "MRS"
   |  print_op MSR = "MSR"
   |  print_op BL = "BL"
   |  print_op B = "B"
   |  print_op SWI = "SWI"
   |  print_op NOP = "NOP"
   |  print_op _ = raise invalidAssemExp

   fun print_cond (SOME EQ) = "EQ"
   |  print_cond (SOME NE) = "NE"
   |  print_cond (SOME GE) = "GE"
   |  print_cond (SOME LT) = "LT"
   |  print_cond (SOME GT) = "GT"
   |  print_cond (SOME LE) = "LE"
   |  print_cond (SOME AL) = "AL"
   |  print_cond (SOME NV) = "NV"
   |  print_cond NONE = ""

   fun print_flag flag =
      if flag then "S"
      else ""

   fun printAlias FP = "FP"
    |  printAlias IP = "IP"
    |  printAlias SP = "SP"
    |  printAlias LR = "LR"
    |  printAlias PC = "PC"   

   val use_alias = ref true;
   val use_capital = ref false;
   val address_stride = ref 1; 

   fun printReg r = 
	if !use_alias andalso r >= 11 then
	   printAlias (toAlias r)
	else "R" ^ Int.toString r 

   fun eval_exp (TEMP e) =
            e
    |  eval_exp (NAME e) =
            Symbol.index e
    |  eval_exp (NCONST e) =
            e
    |  eval_exp (WCONST e) =
            e
    |  eval_exp (TMEM e) =
            e
    |  eval_exp (MEM {reg = r, offset = j, wback = w}) =
            j
    |  eval_exp (REG e) =
            e
    |  eval_exp (WREG e) =
            e
    |  eval_exp (ALIAS e) =
            fromAlias e
    |  eval_exp _ =
	    0

    fun one_exp (TMEM e) =
	     "[" ^ Int.toString e ^ "]"
     |  one_exp (MEM {reg = r, offset = j, wback = w}) =
           (if j = 0 then
                "[" ^ printReg r ^ "]"
           else
                "[" ^ printReg r ^ ", " ^ "#" ^ Int.toString (j * !address_stride) ^ "]") ^
           (if w then "!" else "")
     |  one_exp (TEMP e) =
	     "t" ^ Int.toString e
     |  one_exp (NAME e) =
             Symbol.name e
     |  one_exp (NCONST e) =
             "#" ^ Int.toString e
     |  one_exp (WCONST e) =
             "#" ^ (Int.toString e) ^ "w"
     |  one_exp (REG e) =
             printReg e
     |  one_exp (WREG e) =
             printReg e ^ "!"
     |  one_exp (CALL(f, args)) =
             "BL " ^ (one_exp f)
     |  one_exp (PAIR(e1,e2)) =
             "(" ^ one_exp e1 ^ "," ^ one_exp e2 ^ ")"
     |  one_exp _ =
	     raise invalidAssemExp


    fun toLowerCase str =
                Substring.translate (Char.toString o Char.toLower)
                (Substring.substring (str, 0, String.size str))

    fun formatInst (OPER {oper = (op1, cond1, flag1), src = sl, dst = dl, jump = jl}) =
	let 
	    fun appendBlanks i = if i <= 0 then "" else " " ^ appendBlanks (i-1)  

	    val (sl,dl) = if op1 = LDMFD orelse op1 = STR then (dl,sl)
			  else if op1 = CMP then (sl,[]) 
			  else (sl,dl)

	    val ops0 = (print_op op1 ^ print_cond cond1 ^ print_flag flag1)	
	    val ops1 = ops0 ^ appendBlanks (8 - String.size ops0)

	    val inst =  
        	indent ^ ops1 ^
   
        	(
	 	 if op1 = STMFD orelse op1 = LDMFD then
            	 	(one_exp (hd dl)) ^ ", {" ^ one_exp (hd sl) ^ 
					(List.foldl (fn (n,s) => (s ^ "," ^ one_exp n)) "" (tl sl)) ^ "}"
         	 else
	           	(if null dl then "" else (one_exp (hd dl))) ^
           		(if null sl orelse op1 = B then ""
			 else if null dl then (one_exp (hd sl))
			 else ", " ^ (one_exp (hd sl))
			) ^
			(if null sl then "" 
			 else List.foldl (fn (v,s) => s ^ ", " ^ (one_exp v)) "" (tl sl)) ^
            		(case jl of
                	      NONE => ""
             		   |  SOME labs => Symbol.name (hd labs) ^ " (" ^ Int.toString (Symbol.index (hd labs)) ^ ")")
        		)
        in
	    if !use_capital then inst
	    else toLowerCase inst
	end

   |  formatInst (LABEL {lab = v}) = Symbol.name v ^ ":"

   |  formatInst (MOVE {src = s, dst = d}) =
	let val inst = 	indent ^ "MOV     " ^ (one_exp d) ^ ", " ^ (one_exp s)
	in
	    if !use_capital then inst
	    else toLowerCase inst
        end
end
