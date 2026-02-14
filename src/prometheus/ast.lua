-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- ast.lua
--
-- PURPOSE: This module defines the Abstract Syntax Tree (AST) structure for the Lua obfuscator.
-- An AST is a tree representation of source code where each node represents a construct in the language.
-- This allows the obfuscator to parse, analyze, transform, and regenerate Lua code.
--
-- HOW IT WORKS:
-- 1. The parser converts Lua source code into AST nodes
-- 2. Each AST node has a "kind" that identifies what type of construct it represents
-- 3. Nodes contain relevant data (values, child nodes, scope information, etc.)
-- 4. The compiler can traverse these nodes to generate obfuscated code
-- 5. Transformations can be applied to the AST before code generation

local Ast = {}

-- AstKind: Enumeration of all possible AST node types
-- Each string value identifies a specific construct in the Lua language
local AstKind = {
	-- Misc: Top-level and structural nodes
	TopNode = "TopNode";              -- Root node containing the entire program
	Block = "Block";                  -- A block of statements (like a function body or do-end block)

	-- Statements: Code that performs actions (doesn't return a value)
	ContinueStatement = "ContinueStatement";        -- 'continue' keyword (LuaU feature)
	BreakStatement = "BreakStatement";              -- 'break' keyword (exits loop)
	DoStatement = "DoStatement";                    -- 'do ... end' block
	WhileStatement = "WhileStatement";              -- 'while condition do ... end'
	ReturnStatement = "ReturnStatement";             -- 'return value1, value2, ...'
	RepeatStatement = "RepeatStatement";            -- 'repeat ... until condition'
	ForInStatement = "ForInStatement";               -- 'for var in iterator do ... end'
	ForStatement = "ForStatement";                   -- 'for i = start, stop, step do ... end'
	IfStatement = "IfStatement";                    -- 'if condition then ... elseif ... else ... end'
	FunctionDeclaration = "FunctionDeclaration";    -- 'function name() ... end' (global function)
	LocalFunctionDeclaration = "LocalFunctionDeclaration"; -- 'local function name() ... end'
	LocalVariableDeclaration = "LocalVariableDeclaration"; -- 'local var1, var2 = val1, val2'
	FunctionCallStatement = "FunctionCallStatement"; -- Function call used as statement (no return value used)
	PassSelfFunctionCallStatement = "PassSelfFunctionCallStatement"; -- Method call: obj:method()
	AssignmentStatement = "AssignmentStatement";     -- 'var = value' or 'var1, var2 = val1, val2'

	-- LuaU Compound Statements: Shorthand operators (e.g., x += 5)
	CompoundAddStatement = "CompoundAddStatement";   -- 'x += value' (equivalent to x = x + value)
	CompoundSubStatement = "CompoundSubStatement";   -- 'x -= value'
	CompoundMulStatement = "CompoundMulStatement";    -- 'x *= value'
	CompoundDivStatement = "CompoundDivStatement";   -- 'x /= value'
	CompoundModStatement = "CompoundModStatement";   -- 'x %= value'
	CompoundPowStatement = "CompoundPowStatement";   -- 'x ^= value'
	CompoundConcatStatement = "CompoundConcatStatement"; -- 'x ..= value'

	-- Assignment Index: Used in assignment statements to identify what's being assigned to
	AssignmentIndexing = "AssignmentIndexing";        -- Assignment to table index: t[key] = value
	AssignmentVariable = "AssignmentVariable";       -- Assignment to variable: var = value

	-- Expression Nodes: Code that evaluates to a value (can be used in other expressions)
	BooleanExpression = "BooleanExpression";         -- true or false literal
	NumberExpression = "NumberExpression";          -- Numeric literal (e.g., 42, 3.14)
	StringExpression = "StringExpression";          -- String literal (e.g., "hello")
	NilExpression = "NilExpression";                -- nil literal
	VarargExpression = "VarargExpression";          -- '...' (variable arguments)
	OrExpression = "OrExpression";                  -- 'lhs or rhs' (logical OR)
	AndExpression = "AndExpression";                 -- 'lhs and rhs' (logical AND)
	LessThanExpression = "LessThanExpression";      -- 'lhs < rhs'
	GreaterThanExpression = "GreaterThanExpression"; -- 'lhs > rhs'
	LessThanOrEqualsExpression = "LessThanOrEqualsExpression"; -- 'lhs <= rhs'
	GreaterThanOrEqualsExpression = "GreaterThanOrEqualsExpression"; -- 'lhs >= rhs'
	NotEqualsExpression = "NotEqualsExpression";     -- 'lhs ~= rhs'
	EqualsExpression = "EqualsExpression";           -- 'lhs == rhs'
	StrCatExpression = "StrCatExpression";          -- 'lhs .. rhs' (string concatenation)
	AddExpression = "AddExpression";                -- 'lhs + rhs'
	SubExpression = "SubExpression";                -- 'lhs - rhs'
	MulExpression = "MulExpression";                -- 'lhs * rhs'
	DivExpression = "DivExpression";                -- 'lhs / rhs'
	ModExpression = "ModExpression";                -- 'lhs % rhs' (modulo)
	NotExpression = "NotExpression";                 -- 'not rhs' (logical NOT)
	LenExpression = "LenExpression";                -- '#rhs' (length operator)
	NegateExpression = "NegateExpression";          -- '-rhs' (unary minus)
	PowExpression = "PowExpression";                 -- 'lhs ^ rhs' (exponentiation)
	IndexExpression = "IndexExpression";             -- 'base[index]' (table indexing)
	FunctionCallExpression = "FunctionCallExpression"; -- 'func(args)' (function call that returns value)
	PassSelfFunctionCallExpression = "PassSelfFunctionCallExpression"; -- 'obj:method(args)'
	VariableExpression = "VariableExpression";       -- Variable reference: 'var'
	FunctionLiteralExpression = "FunctionLiteralExpression"; -- Anonymous function: 'function() ... end'
	TableConstructorExpression = "TableConstructorExpression"; -- Table literal: '{key = value, ...}'

	-- Table Entry: Components of table constructors
	TableEntry = "TableEntry";                      -- Unkeyed table entry: '{value}' (indexed by position)
	KeyedTableEntry = "KeyedTableEntry";            -- Keyed table entry: '{key = value}'

	-- Misc
	NopStatement = "NopStatement";                  -- No-operation statement (empty statement)

	IfElseExpression = "IfElseExpression";           -- Ternary-like expression: 'condition and true_value or false_value'
}

-- Operator Precedence Lookup Table
-- This table maps expression types to their precedence levels (higher number = lower precedence)
-- Used by the compiler to determine when parentheses are needed in generated code
-- Example: 2 + 3 * 4 needs parentheses as (2 + (3 * 4)) because * has higher precedence (7) than + (8)
local astKindExpressionLookup = {
	-- Precedence 0: Literals and primitives (highest precedence, no parentheses needed)
	[AstKind.BooleanExpression] = 0;   -- true, false
	[AstKind.NumberExpression] = 0;     -- 42, 3.14
	[AstKind.StringExpression] = 0;     -- "hello"
	[AstKind.NilExpression] = 0;        -- nil
	[AstKind.VarargExpression] = 0;     -- ...
	[AstKind.VariableExpression] = 0;   -- variable names
	[AstKind.AssignmentVariable] = 0;   -- variable in assignment context
	
	-- Precedence 12: Logical OR (lowest precedence)
	[AstKind.OrExpression] = 12;         -- or
	
	-- Precedence 11: Logical AND
	[AstKind.AndExpression] = 11;       -- and
	
	-- Precedence 10: Comparison operators
	[AstKind.LessThanExpression] = 10;              -- <
	[AstKind.GreaterThanExpression] = 10;            -- >
	[AstKind.LessThanOrEqualsExpression] = 10;       -- <=
	[AstKind.GreaterThanOrEqualsExpression] = 10;     -- >=
	[AstKind.NotEqualsExpression] = 10;               -- ~=
	[AstKind.EqualsExpression] = 10;                  -- ==
	
	-- Precedence 9: String concatenation
	[AstKind.StrCatExpression] = 9;     -- ..
	
	-- Precedence 8: Addition and subtraction
	[AstKind.AddExpression] = 8;       -- +
	[AstKind.SubExpression] = 8;       -- -
	
	-- Precedence 7: Multiplication, division, modulo
	[AstKind.MulExpression] = 7;        -- *
	[AstKind.DivExpression] = 7;        -- /
	[AstKind.ModExpression] = 7;       -- %
	
	-- Precedence 5: Unary operators (not, length, negation)
	[AstKind.NotExpression] = 5;       -- not
	[AstKind.LenExpression] = 5;       -- # (length)
	[AstKind.NegateExpression] = 5;    -- - (unary minus)
	
	-- Precedence 4: Exponentiation
	[AstKind.PowExpression] = 4;        -- ^
	
	-- Precedence 3: Function literals and table constructors
	[AstKind.FunctionLiteralExpression] = 3;         -- function() ... end
	[AstKind.TableConstructorExpression] = 3;        -- { ... }
	
	-- Precedence 2: Function calls
	[AstKind.FunctionCallExpression] = 2;            -- func()
	[AstKind.PassSelfFunctionCallExpression] = 2;    -- obj:method()
	
	-- Precedence 1: Indexing (table access)
	[AstKind.IndexExpression] = 1;                   -- table[key]
	[AstKind.AssignmentIndexing] = 1;               -- table[key] in assignment
	
	-- Default: 100 (lowest precedence, always needs parentheses)
}

-- Export AstKind so other modules can use it
Ast.AstKind = AstKind;

-- Convert an AST expression kind to its precedence number
-- Used by the compiler to determine operator precedence when generating code
-- Returns 100 (lowest precedence) if the kind is not found
function Ast.astKindExpressionToNumber(kind)
	return astKindExpressionLookup[kind] or 100;
end

-- Helper function to create a constant node from a Lua value
-- Automatically determines the correct expression type based on the value's type
-- Used when the obfuscator needs to create literal values in the AST
function Ast.ConstantNode(val)
	if type(val) == "nil" then
		return Ast.NilExpression();
	end

	if type(val) == "string" then
		return Ast.StringExpression(val);
	end

	if type(val) == "number" then
		return Ast.NumberExpression(val);
	end

	if type(val) == "boolean" then
		return Ast.BooleanExpression(val);
	end
end



-- ============================================================================
-- NODE CREATION FUNCTIONS
-- ============================================================================
-- Each function below creates an AST node of a specific type.
-- All nodes follow a similar structure:
--   - kind: Identifies the node type (from AstKind enum)
--   - Additional fields: Store node-specific data (values, child nodes, scope info, etc.)
-- ============================================================================

-- Creates a no-operation statement (empty statement)
-- Used when the parser encounters an empty statement or needs a placeholder
function Ast.NopStatement()
	return {
		kind = AstKind.NopStatement;
	}
end

-- Creates a ternary-like expression: condition and true_value or false_value
-- This is Lua's way of doing conditional expressions (Lua doesn't have true ternary operator)
-- Example: (x > 0) and "positive" or "negative"
function Ast.IfElseExpression(condition, true_value, false_value)
	return {
		kind = AstKind.IfElseExpression,
		condition = condition,        -- Expression that evaluates to boolean
		true_value = true_value,     -- Value returned if condition is true
		false_value = false_value     -- Value returned if condition is false
	}
end

-- Creates the root node of the entire AST
-- This is the top-level node that contains the entire program
-- body: The main block of statements (Block node)
-- globalScope: The global variable scope for the entire program
function Ast.TopNode(body, globalScope)
	return {
		kind = AstKind.TopNode,
		body = body,                 -- Main program body (Block node)
		globalScope = globalScope,   -- Global scope containing all top-level variables
	}
end

-- Creates an unkeyed table entry (positional entry)
-- Example: In {1, 2, 3}, each number is a TableEntry
-- value: The expression for the entry's value
function Ast.TableEntry(value)
	return {
		kind = AstKind.TableEntry,
		value = value,                -- Expression node representing the value
	}
end

-- Creates a keyed table entry (key-value pair)
-- Example: In {name = "John", age = 25}, each pair is a KeyedTableEntry
-- key: Expression for the key (can be string literal or any expression)
-- value: Expression for the value
function Ast.KeyedTableEntry(key, value)
	return {
		kind = AstKind.KeyedTableEntry,
		key = key,                   -- Expression node for the key
		value = value,               -- Expression node for the value
	}
end

-- Creates a table constructor expression
-- Example: {1, 2, name = "test", [key] = value}
-- entries: Array of TableEntry and/or KeyedTableEntry nodes
function Ast.TableConstructorExpression(entries)
	return {
		kind = AstKind.TableConstructorExpression,
		entries = entries,           -- Array of table entry nodes
	};
end

-- Creates a block of statements (like a function body or do-end block)
-- statements: Array of statement nodes to execute in order
-- scope: The variable scope for this block (tracks local variables)
function Ast.Block(statements, scope)
	return {
		kind = AstKind.Block,
		statements = statements,     -- Array of statement nodes
		scope = scope,              -- Scope object tracking variables in this block
	}
end

-- Creates a break statement (exits the innermost loop)
-- loop: Reference to the loop node this break belongs to
-- scope: The scope where this break statement exists
function Ast.BreakStatement(loop, scope)
	return {
		kind = AstKind.BreakStatement,
		loop = loop,                -- Reference to the loop being broken out of
		scope = scope,              -- Scope where break exists
	}
end

-- Creates a continue statement (skips to next iteration of loop)
-- Note: 'continue' is a LuaU feature, not available in standard Lua
-- loop: Reference to the loop node this continue belongs to
-- scope: The scope where this continue statement exists
function Ast.ContinueStatement(loop, scope)
	return {
		kind = AstKind.ContinueStatement,
		loop = loop,                -- Reference to the loop being continued
		scope = scope,              -- Scope where continue exists
	}
end

-- Creates a method call statement (obj:method(args))
-- This is a statement version (return value not used)
-- base: Expression for the object (e.g., 'obj' in obj:method())
-- passSelfFunctionName: Expression for the method name
-- args: Array of argument expression nodes
function Ast.PassSelfFunctionCallStatement(base, passSelfFunctionName, args)
	return {
		kind = AstKind.PassSelfFunctionCallStatement,
		base = base,                        -- Object expression (e.g., 'obj')
		passSelfFunctionName = passSelfFunctionName,  -- Method name expression
		args = args,                       -- Array of argument expressions
	}
end

-- Creates an assignment statement
-- Example: x = 5, or x, y = 1, 2, or t[key] = value
-- lhs: Array of left-hand side nodes (variables or table indices being assigned to)
-- rhs: Array of right-hand side expression nodes (values being assigned)
-- Note: Multiple assignment is supported (e.g., x, y = 1, 2)
function Ast.AssignmentStatement(lhs, rhs)
	-- Safety check: assignment must have at least one left-hand side
	if(#lhs < 1) then
		print(debug.traceback());
		error("Something went wrong!");
	end
	return {
		kind = AstKind.AssignmentStatement,
		lhs = lhs,                  -- Array of AssignmentVariable or AssignmentIndexing nodes
		rhs = rhs,                  -- Array of expression nodes (values to assign)
	}
end

-- ============================================================================
-- COMPOUND ASSIGNMENT STATEMENTS (LuaU feature)
-- ============================================================================
-- These are shorthand operators that combine assignment with an operation
-- Example: x += 5 is equivalent to x = x + 5

-- Creates x += value (adds value to x and assigns result back to x)
function Ast.CompoundAddStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundAddStatement,
		lhs = lhs,                  -- Variable or table index being modified (left-hand side)
		rhs = rhs,                  -- Expression to add (right-hand side)
	}
end

-- Creates x -= value (subtracts value from x)
function Ast.CompoundSubStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundSubStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

-- Creates x *= value (multiplies x by value)
function Ast.CompoundMulStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundMulStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

-- Creates x /= value (divides x by value)
function Ast.CompoundDivStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundDivStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

-- Creates x ^= value (raises x to the power of value)
function Ast.CompoundPowStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundPowStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

-- Creates x %= value (x modulo value)
function Ast.CompoundModStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundModStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

-- Creates x ..= value (concatenates value to x)
function Ast.CompoundConcatStatement(lhs, rhs)
	return {
		kind = AstKind.CompoundConcatStatement,
		lhs = lhs,
		rhs = rhs,
	}
end

-- ============================================================================
-- CONTROL FLOW STATEMENTS
-- ============================================================================

-- Creates a function call statement (return value not used)
-- Example: print("hello") when used as a statement
-- base: Expression for the function to call
-- args: Array of argument expression nodes
function Ast.FunctionCallStatement(base, args)
	return {
		kind = AstKind.FunctionCallStatement,
		base = base,                -- Expression node for the function (e.g., VariableExpression for 'print')
		args = args,                -- Array of argument expression nodes
	}
end

-- Creates a return statement
-- Example: return x, y, z
-- args: Array of expression nodes to return (can be empty for 'return' with no values)
function Ast.ReturnStatement(args)
	return {
		kind = AstKind.ReturnStatement,
		args = args,                -- Array of expression nodes to return
	}
end

-- Creates a do-end block statement
-- Example: do ... end (creates a new scope)
-- body: Block node containing the statements inside the do-end block
function Ast.DoStatement(body)
	return {
		kind = AstKind.DoStatement,
		body = body,                -- Block node with statements inside do-end
	}
end

-- Creates a while loop statement
-- Example: while condition do ... end
-- body: Block node with loop body statements
-- condition: Expression node that evaluates to boolean (loop continues while true)
-- parentScope: The scope that contains this while loop
function Ast.WhileStatement(body, condition, parentScope)
	return {
		kind = AstKind.WhileStatement,
		body = body,                -- Block node with loop body
		condition = condition,      -- Expression node for the loop condition
		parentScope = parentScope, -- Parent scope (for variable resolution)
	}
end

-- Creates a for-in loop statement (generic for loop)
-- Example: for key, value in pairs(table) do ... end
-- scope: The scope for variables declared in this loop
-- vars: Array of variable names (e.g., ["key", "value"])
-- expressions: Array of expression nodes (the iterator function and its arguments)
-- body: Block node with loop body statements
-- parentScope: The scope that contains this for-in loop
function Ast.ForInStatement(scope, vars, expressions, body, parentScope)
	return {
		kind = AstKind.ForInStatement,
		scope = scope,              -- Scope for loop variables
		ids = vars,                 -- Array of variable identifiers (same as vars)
		vars = vars,                -- Array of variable names being iterated
		expressions = expressions,   -- Array of expressions (iterator function and args)
		body = body,                -- Block node with loop body
		parentScope = parentScope,  -- Parent scope
	}
end

-- Creates a numeric for loop statement
-- Example: for i = 1, 10, 2 do ... end
-- scope: The scope for the loop variable
-- id: Variable identifier for the loop counter
-- initialValue: Expression for starting value
-- finalValue: Expression for ending value
-- incrementBy: Expression for step size (optional, defaults to 1)
-- body: Block node with loop body statements
-- parentScope: The scope that contains this for loop
function Ast.ForStatement(scope, id, initialValue, finalValue, incrementBy, body, parentScope)
	return {
		kind = AstKind.ForStatement,
		scope = scope,              -- Scope for loop variable
		id = id,                    -- Variable identifier for loop counter
		initialValue = initialValue, -- Expression for starting value
		finalValue = finalValue,    -- Expression for ending value
		incrementBy = incrementBy,   -- Expression for step size (can be nil for default 1)
		body = body,                -- Block node with loop body
		parentScope = parentScope,  -- Parent scope
	}
end

-- Creates a repeat-until loop statement
-- Example: repeat ... until condition
-- condition: Expression node for the loop condition (loop continues until this is true)
-- body: Block node with loop body statements
-- parentScope: The scope that contains this repeat loop
function Ast.RepeatStatement(condition, body, parentScope)
	return {
		kind = AstKind.RepeatStatement,
		body = body,                -- Block node with loop body
		condition = condition,      -- Expression node for the until condition
		parentScope = parentScope,  -- Parent scope
	}
end

-- Creates an if-then-elseif-else statement
-- Example: if x > 0 then ... elseif x < 0 then ... else ... end
-- condition: Expression node for the if condition
-- body: Block node with statements for the 'then' branch
-- elseifs: Array of {condition, body} pairs for elseif branches (can be empty)
-- elsebody: Block node for the else branch (can be nil if no else)
function Ast.IfStatement(condition, body, elseifs, elsebody)
	return {
		kind = AstKind.IfStatement,
		condition = condition,      -- Expression for the if condition
		body = body,                -- Block node for the 'then' branch
		elseifs = elseifs,          -- Array of {condition, body} pairs for elseif branches
		elsebody = elsebody,        -- Block node for the else branch (nil if no else)
	}
end

-- ============================================================================
-- FUNCTION AND VARIABLE DECLARATIONS
-- ============================================================================

-- Creates a global function declaration
-- Example: function myFunc(x, y) ... end
-- scope: The scope where this function is declared
-- id: Variable identifier for the function name
-- indices: Array of expression nodes for nested table access (e.g., table.func or table[key].func)
-- args: Array of variable identifiers for function parameters
-- body: Block node containing the function body
-- Note: baseScope and baseId are stored for obfuscation purposes (to track original names)
function Ast.FunctionDeclaration(scope, id, indices, args, body)
	return {
		kind = AstKind.FunctionDeclaration,
		scope = scope,              -- Current scope (may change during obfuscation)
		baseScope = scope,          -- Original scope (preserved for reference)
		id = id,                    -- Current variable identifier (may be obfuscated)
		baseId = id,                -- Original identifier (preserved for reference)
		indices = indices,          -- Array of expressions for nested access (e.g., [table, key])
		args = args,                -- Array of parameter identifiers
		body = body,                -- Block node with function body
		getName = function(self)   -- Helper method to get the variable name from scope
			return self.scope:getVariableName(self.id);
		end,
	}
end

-- Creates a local function declaration
-- Example: local function myFunc(x, y) ... end
-- scope: The scope where this function is declared
-- id: Variable identifier for the function name
-- args: Array of variable identifiers for function parameters
-- body: Block node containing the function body
function Ast.LocalFunctionDeclaration(scope, id, args, body)
	return {
		kind = AstKind.LocalFunctionDeclaration,
		scope = scope,              -- Scope where function is declared
		id = id,                    -- Variable identifier for function name
		args = args,                -- Array of parameter identifiers
		body = body,                -- Block node with function body
		getName = function(self)   -- Helper method to get the variable name
			return self.scope:getVariableName(self.id);
		end,
	}
end

-- Creates a local variable declaration
-- Example: local x, y = 1, 2
-- scope: The scope where these variables are declared
-- ids: Array of variable identifiers being declared
-- expressions: Array of expression nodes for initial values (can be shorter than ids)
function Ast.LocalVariableDeclaration(scope, ids, expressions)
	return {
		kind = AstKind.LocalVariableDeclaration,
		scope = scope,              -- Scope where variables are declared
		ids = ids,                  -- Array of variable identifiers
		expressions = expressions,   -- Array of initial value expressions (nil if no initial value)
	}
end

-- ============================================================================
-- LITERAL EXPRESSIONS (Constant Values)
-- ============================================================================
-- These represent literal values in the code. They are marked as isConstant = true
-- because their values are known at compile time and never change.

-- Creates a vararg expression (...)
-- Used in function parameters to accept variable number of arguments
-- Example: function f(...) end
function Ast.VarargExpression()
	return {
		kind = AstKind.VarargExpression;
		isConstant = false,         -- Varargs are not constant (value depends on call)
	}
end

-- Creates a boolean literal expression
-- Example: true or false
-- value: The boolean value (true or false)
function Ast.BooleanExpression(value)
	return {
		kind = AstKind.BooleanExpression,
		isConstant = true,          -- Boolean literals are always constant
		value = value,              -- The boolean value
	}
end

-- Creates a nil literal expression
-- Example: nil
function Ast.NilExpression()
	return {
		kind = AstKind.NilExpression,
		isConstant = true,          -- nil is always constant
		value = nil,                -- Always nil
	}
end

-- Creates a number literal expression
-- Example: 42, 3.14, -10
-- value: The numeric value
function Ast.NumberExpression(value)
	return {
		kind = AstKind.NumberExpression,
		isConstant = true,          -- Number literals are always constant
		value = value,              -- The numeric value
	}
end

-- Creates a string literal expression
-- Example: "hello", 'world', [[multiline]]
-- value: The string value
function Ast.StringExpression(value)
	return {
		kind = AstKind.StringExpression,
		isConstant = true,          -- String literals are always constant
		value = value,              -- The string value
	}
end

-- ============================================================================
-- BINARY EXPRESSIONS (Operations with Two Operands)
-- ============================================================================
-- These functions create expression nodes for binary operations.
-- They support "constant folding" optimization: if both operands are constants,
-- the expression can be evaluated at compile time and replaced with the result.
-- 
-- The 'simplify' parameter enables constant folding when true.
-- Example: 2 + 3 can be simplified to 5 at compile time.

-- Creates a logical OR expression: lhs or rhs
-- Example: x or y, or true or false (can be simplified to true)
-- lhs: Left-hand side expression node
-- rhs: Right-hand side expression node
-- simplify: If true and both operands are constants, evaluates and returns result
function Ast.OrExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value or rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.OrExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a logical AND expression: lhs and rhs
function Ast.AndExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value and rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.AndExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a less-than comparison: lhs < rhs
function Ast.LessThanExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value < rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.LessThanExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a greater-than comparison: lhs > rhs
function Ast.GreaterThanExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value > rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.GreaterThanExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a less-than-or-equal comparison: lhs <= rhs
function Ast.LessThanOrEqualsExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value <= rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.LessThanOrEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a greater-than-or-equal comparison: lhs >= rhs
function Ast.GreaterThanOrEqualsExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value >= rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.GreaterThanOrEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a not-equal comparison: lhs ~= rhs
function Ast.NotEqualsExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value ~= rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.NotEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates an equality comparison: lhs == rhs
function Ast.EqualsExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value == rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.EqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a string concatenation expression: lhs .. rhs
function Ast.StrCatExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value .. rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.StrCatExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates an addition expression: lhs + rhs
function Ast.AddExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value + rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.AddExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a subtraction expression: lhs - rhs
function Ast.SubExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value - rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.SubExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a multiplication expression: lhs * rhs
function Ast.MulExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value * rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.MulExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a division expression: lhs / rhs
-- Note: Checks for division by zero before simplifying
function Ast.DivExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant and rhs.value ~= 0) then
		local success, val = pcall(function() return lhs.value / rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.DivExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a modulo expression: lhs % rhs
function Ast.ModExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value % rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.ModExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- ============================================================================
-- UNARY EXPRESSIONS (Operations with One Operand)
-- ============================================================================

-- Creates a logical NOT expression: not rhs
function Ast.NotExpression(rhs, simplify)
	if(simplify and rhs.isConstant) then
		local success, val = pcall(function() return not rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.NotExpression,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a unary negation expression: -rhs
function Ast.NegateExpression(rhs, simplify)
	if(simplify and rhs.isConstant) then
		local success, val = pcall(function() return -rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.NegateExpression,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates a length expression: #rhs (returns length of string or table)
function Ast.LenExpression(rhs, simplify)
	if(simplify and rhs.isConstant) then
		local success, val = pcall(function() return #rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.LenExpression,
		rhs = rhs,
		isConstant = false,
	}
end

-- Creates an exponentiation expression: lhs ^ rhs
function Ast.PowExpression(lhs, rhs, simplify)
	if(simplify and rhs.isConstant and lhs.isConstant) then
		local success, val = pcall(function() return lhs.value ^ rhs.value end);
		if success then
			return Ast.ConstantNode(val);
		end
	end

	return {
		kind = AstKind.PowExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	}
end

-- ============================================================================
-- INDEXING AND FUNCTION CALL EXPRESSIONS
-- ============================================================================

-- Creates a table indexing expression: base[index]
-- Example: table[key], array[1], obj.field
-- base: Expression node for the table/object being indexed
-- index: Expression node for the key/index
function Ast.IndexExpression(base, index)
	return {
		kind = AstKind.IndexExpression,
		base = base,                 -- Expression for the table/object
		index = index,               -- Expression for the key/index
		isConstant = false,          -- Indexing is rarely constant (depends on runtime values)
	}
end

-- Creates an assignment indexing node (used in assignment statements)
-- Example: In 'table[key] = value', this represents 'table[key]'
-- base: Expression node for the table being indexed
-- index: Expression node for the key
function Ast.AssignmentIndexing(base, index)
	return {
		kind = AstKind.AssignmentIndexing,
		base = base,                 -- Expression for the table
		index = index,               -- Expression for the key
		isConstant = false,
	}
end

-- Creates a method call expression: base:method(args)
-- This is the expression version (return value is used)
-- Example: result = obj:method(arg1, arg2)
-- base: Expression for the object
-- passSelfFunctionName: Expression for the method name
-- args: Array of argument expression nodes
function Ast.PassSelfFunctionCallExpression(base, passSelfFunctionName, args)
	return {
		kind = AstKind.PassSelfFunctionCallExpression,
		base = base,                        -- Object expression
		passSelfFunctionName = passSelfFunctionName,  -- Method name expression
		args = args,                       -- Array of argument expressions
	}
end

-- Creates a function call expression: base(args)
-- This is the expression version (return value is used)
-- Example: result = func(arg1, arg2)
-- base: Expression node for the function to call
-- args: Array of argument expression nodes
function Ast.FunctionCallExpression(base, args)
	return {
		kind = AstKind.FunctionCallExpression,
		base = base,                -- Expression node for the function
		args = args,                -- Array of argument expressions
	}
end

-- ============================================================================
-- VARIABLE EXPRESSIONS
-- ============================================================================

-- Creates a variable reference expression
-- Example: x, myVar, table.field (when used as a value)
-- scope: The scope where this variable is referenced
-- id: Variable identifier
-- Note: Calls scope:addReference() to track that this variable is being used
function Ast.VariableExpression(scope, id)
	scope:addReference(id);  -- Track variable usage for obfuscation analysis
	return {
		kind = AstKind.VariableExpression, 
		scope = scope,              -- Scope containing the variable
		id = id,                    -- Variable identifier
		getName = function(self)   -- Helper method to get the variable name from scope
			return self.scope.getVariableName(self.id);
		end,
	}
end

-- Creates an assignment variable node (used in assignment statements)
-- Example: In 'x = 5', this represents 'x'
-- scope: The scope where this variable is declared/assigned
-- id: Variable identifier
-- Note: Calls scope:addReference() to track variable usage
function Ast.AssignmentVariable(scope, id)
	scope:addReference(id);  -- Track variable usage
	return {
		kind = AstKind.AssignmentVariable, 
		scope = scope,              -- Scope containing the variable
		id = id,                    -- Variable identifier
		getName = function(self)   -- Helper method to get the variable name
			return self.scope.getVariableName(self.id);
		end,
	}
end

-- ============================================================================
-- FUNCTION LITERAL EXPRESSIONS
-- ============================================================================

-- Creates an anonymous function literal expression
-- Example: function(x, y) return x + y end
-- args: Array of variable identifiers for function parameters
-- body: Block node containing the function body
function Ast.FunctionLiteralExpression(args, body)
	return {
		kind = AstKind.FunctionLiteralExpression,
		args = args,                -- Array of parameter identifiers
		body = body,                -- Block node with function body
	}
end

-- ============================================================================
-- MODULE EXPORT
-- ============================================================================

return Ast;
