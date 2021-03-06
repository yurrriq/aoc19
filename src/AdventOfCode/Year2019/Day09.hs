module AdventOfCode.Year2019.Day09
  ( main,
    partOne,
    evalStack,
    evalStack',
    await',
  )
where

import Conduit
import Control.Monad (liftM2, when)
import Control.Monad.State (get, lift, put)
import Control.Monad.Trans.State.Strict (StateT, execStateT)
import Data.Conduit.Lift (evalStateC)
import Data.Digits (digitsRev)
import Data.Vector
  ( (!),
    Vector,
    fromList,
    modify,
  )
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as MV
import System.Environment (getArgs)
import Text.Trifecta
  ( Parser,
    comma,
    integer,
    parseFromFile,
    sepBy,
  )

-- -------------------------------------------------------------------- [ Main ]

main :: IO ()
main =
  do
    putStr "Part One: "
    partOne =<< getInputFilename

-- ------------------------------------------------------------------- [ Parts ]

partOne :: FilePath -> IO ()
partOne fname =
  do
    Just input <- parseFromFile stack fname
    boost <- runConduit $ yield 1 .| evalStack input .| sinkList
    print boost

-- ------------------------------------------------------------------- [ Types ]

type Program = StateT ProgramState IO

type Stack = Vector Int

data ProgramState
  = ProgramState
      { _stack :: Stack,
        _pointer :: Int,
        _debug :: Bool,
        _relativeBase :: Int
      }
  deriving (Eq, Show)

data Instruction
  = Add Value Value Int
  | Multiply Value Value Int
  | Set Value Int
  | Output Value
  | JumpIfTrue Value Value
  | JumpIfFalse Value Value
  | LessThan Value Value Int
  | Equals Value Value Int
  | AdjustRelativeBase Value
  | End
  deriving (Eq, Show)

data Value
  = PositionMode Int
  | ImmediateMode Int
  | RelativeMode Int
  deriving (Eq, Show)

-- ------------------------------------------------------------------ [ Parser ]

stack :: Parser (Vector Int)
stack = fromList . map fromInteger <$> (integer `sepBy` comma)

-- -------------------------------------------------------- [ Running Programs ]

runProgram :: ConduitT Int Int Program ()
runProgram =
  do
    opCode <- lift nextInt
    when (opCode /= 99) $
      do
        debugState
        instruction <- getInstruction (normalizeOpCode opCode)
        debugInstruction instruction
        runInstruction instruction
        debugState
        runProgram

debugMode :: Program ()
debugMode =
  do
    lift $ putStrLn "Enabling debug mode"
    state <- get
    put $ state {_debug = True}

debugInstruction :: Instruction -> ConduitT a b Program ()
debugInstruction ins =
  do
    st <- get
    when (_debug st) $
      lift (lift (print ins))

debugState :: ConduitT a b Program ()
debugState =
  do
    st <- get
    when (_debug st) $
      lift (lift (print st))

getInstruction :: [Int] -> ConduitT Int Int Program Instruction
getInstruction [1, 0, c, b] =
  lift $ Add <$> (mkValue c <$> nextInt) <*> (mkValue b <$> nextInt) <*> nextInt
getInstruction [2, 0, c, b] =
  lift $ Multiply <$> (mkValue c <$> nextInt) <*> (mkValue b <$> nextInt) <*> nextInt
getInstruction [3, 0, c, 0] =
  do
    input <- await'
    lift $ Set (mkValue c input) <$> nextInt
getInstruction [4, 0, c, 0] =
  lift $ Output <$> (mkValue c <$> nextInt)
getInstruction [5, 0, c, b] =
  lift $ JumpIfTrue <$> (mkValue c <$> nextInt) <*> (mkValue b <$> nextInt)
getInstruction [6, 0, c, b] =
  lift $ JumpIfFalse <$> (mkValue c <$> nextInt) <*> (mkValue b <$> nextInt)
getInstruction [7, 0, c, b] =
  lift $ LessThan <$> (mkValue c <$> nextInt) <*> (mkValue b <$> nextInt) <*> nextInt
getInstruction [8, 0, c, b] =
  lift $ Equals <$> (mkValue c <$> nextInt) <*> (mkValue b <$> nextInt) <*> nextInt
getInstruction [9, 0, c, 0] =
  lift $ AdjustRelativeBase <$> (mkValue c <$> nextInt)
getInstruction ins = error $ "Invalid instruction" ++ show ins

runInstruction :: Instruction -> ConduitT Int Int Program ()
runInstruction (Add vx vy dst) =
  lift $ flip setValue dst =<< (+) <$> handleValue vx <*> handleValue vy
runInstruction (Multiply vx vy dst) =
  lift $ flip setValue dst =<< (*) <$> handleValue vx <*> handleValue vy
runInstruction (Set vx dst) =
  lift $ flip setValue dst =<< handleValue vx
runInstruction (Output vx) =
  yield =<< lift (handleValue vx)
runInstruction (JumpIfTrue vx vy) =
  lift $ do
    x <- handleValue vx
    when (x /= 0) $
      do
        state <- get
        y <- handleValue vy
        put $ state {_pointer = y}
runInstruction (JumpIfFalse vx vy) =
  lift $ do
    x <- handleValue vx
    when (x == 0) $
      do
        state <- get
        y <- handleValue vy
        put $ state {_pointer = y}
runInstruction (LessThan vx vy dst) =
  lift $ do
    lt <- (<) <$> handleValue vx <*> handleValue vy
    if lt
      then setValue 1 dst
      else setValue 0 dst
runInstruction (Equals vx vy dst) =
  lift $ do
    eq <- (==) <$> handleValue vx <*> handleValue vy
    if eq
      then setValue 1 dst
      else setValue 0 dst
runInstruction (AdjustRelativeBase vx) =
  lift $ do
    state <- get
    x <- handleValue vx
    put $ state {_relativeBase = _relativeBase state + x}
runInstruction End = pure ()

evalStack :: Stack -> ConduitT Int Int IO ()
evalStack st = evalStateC (initialState {_stack = st}) runProgram

evalStack' :: Stack -> ConduitT Int Int IO ()
evalStack' st =
  do
    state <- lift $ execStateT debugMode (initialState {_stack = st})
    evalStateC state runProgram

-- -------------------------------------------------- [ Manipulating the Stack ]
-- TODO: Lenses

setValue :: Int -> Int -> Program ()
setValue x dst =
  do
    growStack dst
    state <- get
    put $ state {_stack = modify (\v -> MV.write v dst x) (_stack state)}

growStack :: Int -> Program ()
growStack dst =
  do
    state <- get
    let size = length (_stack state)
    when (dst >= size)
      $ put
      $ state {_stack = _stack state <> V.replicate (1 + dst - size) 0}

incrementPointer :: Program ()
incrementPointer =
  do
    state <- get
    put $ state {_pointer = _pointer state + 1}

nextInt :: Program Int
nextInt =
  do
    vx <- liftM2 (!) _stack _pointer <$> get
    incrementPointer
    pure vx

handleValue :: Value -> Program Int
handleValue (PositionMode i) =
  do
    growStack i
    flip V.indexM i =<< _stack <$> get
handleValue (ImmediateMode n) = pure n
handleValue (RelativeMode n) =
  do
    relativeBase <- _relativeBase <$> get
    handleValue (PositionMode (relativeBase + n))

-- -------------------------------------------------------- [ Helper Functions ]

initialState :: ProgramState
initialState =
  ProgramState
    { _debug = False,
      _pointer = 0,
      _relativeBase = 0,
      _stack = V.empty
    }

normalizeOpCode :: Int -> [Int]
normalizeOpCode ds = take 4 $ digitsRev 10 ds ++ repeat 0

mkValue :: Int -> Int -> Value
mkValue 0 = PositionMode
mkValue 1 = ImmediateMode
mkValue 2 = RelativeMode
mkValue _ = error "Invalid parameter mode"

getInputFilename :: IO FilePath
getInputFilename =
  do
    args <- getArgs
    case args of
      [fname] -> pure fname
      [] -> error "Must specify input filename"
      _ -> error "Too many args"

await' :: Monad m => ConduitT i o m i
await' = maybe (error "Missing input") pure =<< await
