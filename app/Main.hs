import Data.Semigroup ((<>))
import System.IO

import CMark
import Data.Text hiding (empty, foldl)
import Data.Text.IO as TIO
import Options.Applicative

import Text.CommonMark.Sub

data HeadingPattern = HeadingPattern Level Text deriving (Eq, Ord, Show)

data Extraction = Extraction 
    { inputFilePath :: FilePath
    , headingPattern :: HeadingPattern
    , columnWidth :: Maybe Int
    } deriving (Eq, Ord, Show)

headingLevel :: Parser HeadingPattern
headingLevel =
    foldl (<|>) empty parsers
  where
    levels :: [Level]
    levels = [1..6]
    parsers :: [Parser HeadingPattern]
    parsers =
        [ (HeadingPattern l . pack) <$> strOption
              (  long ("h" ++ show l)
              <> metavar "TITLE"
              <> help ("Extract the section with the heading level " ++
                       show l ++ ".  Mutually exclusive with other --h* " ++
                       "options")
              )
        | l <- levels
        ]

parser :: Parser Extraction
parser = Extraction
    <$> strArgument (  metavar "FILE"
                    <> help "CommonMark/Markdown text to extract from"
                    )
    <*> headingLevel
    <*> ( Just . read <$> strOption
            (  long "columns"
            <> short 'c'
            <> metavar "WIDTH"
            <> help ("Limit the maximum characters per line of the output.  " ++
                     "No limit by default")
            )
        <|> pure Nothing
        )

parserInfo :: ParserInfo Extraction
parserInfo = info (parser <**> helper) $
    fullDesc <> progDesc "Extract a part from CommonMark/Markdown docs."

withInputFile :: Extraction -> (Handle -> IO r) -> IO r
withInputFile Extraction { inputFilePath = "-" } action' = do
    let i = stdin
    r <- action' i
    hClose i
    return r
withInputFile Extraction { inputFilePath = i } action' =
    withFile i ReadMode action'

extract :: Extraction -> IO ()
extract e@Extraction { headingPattern = (HeadingPattern level title)
                     , columnWidth = width
                     } = do
    text <- withInputFile e TIO.hGetContents
    let doc = commonmarkToNode [] text
        node = extractSection level title doc
        result = nodeToCommonmark [] width node
    TIO.putStrLn result

main :: IO ()
main = execParser parserInfo >>= extract
