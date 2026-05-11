// Bundled from sudoku-core 3.0.3.
// MIT License. Copyright (c) 2023 Komeil Mehranfar (komeilmehranfar.com).
var SudokuCore = (() => {
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // ../../../../private/tmp/sudoku-core-inspect/package/dist/esm/index.js
  var esm_exports = {};
  __export(esm_exports, {
    analyze: () => analyze,
    generate: () => generate,
    hint: () => hint,
    solve: () => solve
  });

  // ../../../../private/tmp/sudoku-core-inspect/package/dist/esm/constants.js
  var BOARD_SIZE = 9;
  var CANDIDATES = [1, 2, 3, 4, 5, 6, 7, 8, 9];
  var NULL_CANDIDATE_LIST = new Array(9).fill(null);
  var DIFFICULTY_EASY = "easy";
  var DIFFICULTY_MEDIUM = "medium";
  var DIFFICULTY_HARD = "hard";
  var DIFFICULTY_EXPERT = "expert";
  var DIFFICULTY_MASTER = "master";

  // ../../../../private/tmp/sudoku-core-inspect/package/dist/esm/sudoku-solver.js
  function isValid(board, index, num) {
    const row = Math.floor(index / 9);
    const col = index % 9;
    for (let i = 0; i < 9; i++) {
      if (board[row * 9 + i] === num || board[col + 9 * i] === num) {
        return false;
      }
    }
    const startRow = row - row % 3;
    const startCol = col - col % 3;
    for (let i = 0; i < 3; i++) {
      for (let j = 0; j < 3; j++) {
        if (board[(startRow + i) * 9 + startCol + j] === num) {
          return false;
        }
      }
    }
    return true;
  }
  var solutionCount = 0;
  function solveSudoku(board) {
    for (let i = 0; i < 81; i++) {
      if (!board[i]) {
        for (let num = 1; num <= 9; num++) {
          if (isValid(board, i, num)) {
            board[i] = num;
            solveSudoku(board);
            if (solutionCount > 1) {
              return false;
            }
            board[i] = null;
          }
        }
        return false;
      }
    }
    solutionCount++;
    if (solutionCount > 1) {
      return false;
    }
    return true;
  }
  function isUniqueSolution(board) {
    solutionCount = 0;
    solveSudoku([...board]);
    return solutionCount === 1;
  }

  // ../../../../private/tmp/sudoku-core-inspect/package/dist/esm/utils.js
  var contains = (array, object) => {
    for (let i = 0; i < array.length; i++) {
      if (array[i] === object) {
        return true;
      }
    }
    return false;
  };
  var generateHouseIndexList = (boardSize) => {
    const groupOfHouses = [[], [], []];
    const boxSideSize = Math.sqrt(boardSize);
    for (let i = 0; i < boardSize; i++) {
      const horizontalRow = [];
      const verticalRow = [];
      const box = [];
      for (let j = 0; j < boardSize; j++) {
        horizontalRow.push(boardSize * i + j);
        verticalRow.push(boardSize * j + i);
        if (j < boxSideSize) {
          for (let k = 0; k < boxSideSize; k++) {
            const a = Math.floor(i / boxSideSize) * boardSize * boxSideSize;
            const b = i % boxSideSize * boxSideSize;
            const boxStartIndex = a + b;
            box.push(boxStartIndex + boardSize * j + k);
          }
        }
      }
      groupOfHouses[0].push(horizontalRow);
      groupOfHouses[1].push(verticalRow);
      groupOfHouses[2].push(box);
    }
    return groupOfHouses;
  };
  var isBoardFinished = (board) => {
    return new Array(BOARD_SIZE * BOARD_SIZE).fill(null).every((_, i) => board[i].value !== null);
  };
  var isEasyEnough = (difficulty, currentDifficulty) => {
    switch (currentDifficulty) {
      case DIFFICULTY_EASY:
        return true;
      case DIFFICULTY_MEDIUM:
        return difficulty !== DIFFICULTY_EASY;
      case DIFFICULTY_HARD:
        return difficulty !== DIFFICULTY_EASY && difficulty !== DIFFICULTY_MEDIUM;
      case DIFFICULTY_EXPERT:
        return difficulty !== DIFFICULTY_EASY && difficulty !== DIFFICULTY_MEDIUM && difficulty !== DIFFICULTY_HARD;
      case DIFFICULTY_MASTER:
        return difficulty !== DIFFICULTY_EASY && difficulty !== DIFFICULTY_MEDIUM && difficulty !== DIFFICULTY_HARD && difficulty !== DIFFICULTY_EXPERT;
    }
  };
  var isHardEnough = (difficulty, currentDifficulty) => {
    switch (difficulty) {
      case DIFFICULTY_EASY:
        return true;
      case DIFFICULTY_MEDIUM:
        return currentDifficulty !== DIFFICULTY_EASY;
      case DIFFICULTY_HARD:
        return currentDifficulty !== DIFFICULTY_EASY && currentDifficulty !== DIFFICULTY_MEDIUM;
      case DIFFICULTY_EXPERT:
        return currentDifficulty !== DIFFICULTY_EASY && currentDifficulty !== DIFFICULTY_MEDIUM && currentDifficulty !== DIFFICULTY_HARD;
      case DIFFICULTY_MASTER:
        return currentDifficulty !== DIFFICULTY_EASY && currentDifficulty !== DIFFICULTY_MEDIUM && currentDifficulty !== DIFFICULTY_HARD && currentDifficulty !== DIFFICULTY_EXPERT;
    }
  };
  var getRemovalCountBasedOnDifficulty = (difficulty) => {
    switch (difficulty) {
      case DIFFICULTY_EASY:
        return BOARD_SIZE * BOARD_SIZE - 38;
      case DIFFICULTY_MEDIUM:
        return BOARD_SIZE * BOARD_SIZE - 30;
      case DIFFICULTY_HARD:
        return BOARD_SIZE * BOARD_SIZE - 20;
      default:
        return BOARD_SIZE * BOARD_SIZE - 17;
    }
  };
  var addValueToCellIndex = (board, cellIndex, value) => {
    board[cellIndex].value = value;
    if (value !== null) {
      board[cellIndex].candidates = NULL_CANDIDATE_LIST.slice();
    }
  };
  var getRandomCandidateOfCell = (candidates) => {
    const randomIndex = Math.floor(Math.random() * candidates.length);
    return candidates[randomIndex];
  };
  var calculateBoardDifficulty = (usedStrategies, strategies) => {
    const validUsedStrategies = usedStrategies.filter(Boolean);
    const totalScore = validUsedStrategies.reduce((accumulatedScore, frequency, i) => {
      const strategy = strategies[i];
      return accumulatedScore + frequency * strategy.score;
    }, 0);
    let difficulty = validUsedStrategies.length < 3 ? DIFFICULTY_EASY : validUsedStrategies.length < 4 ? DIFFICULTY_MEDIUM : DIFFICULTY_HARD;
    if (totalScore > 750)
      difficulty = DIFFICULTY_EXPERT;
    if (totalScore > 2200)
      difficulty = DIFFICULTY_MASTER;
    return {
      difficulty,
      score: totalScore
    };
  };

  // ../../../../private/tmp/sudoku-core-inspect/package/dist/esm/sudoku.js
  var GROUP_OF_HOUSES = generateHouseIndexList(BOARD_SIZE);
  function createSudokuInstance(options = {}) {
    const { onError, onUpdate, onFinish, initBoard, difficulty = DIFFICULTY_MEDIUM } = options;
    let board = [];
    let usedStrategies = [];
    const resetCandidates = () => {
      board = new Array(BOARD_SIZE * BOARD_SIZE).fill(null).map((_, index) => Object.assign(Object.assign({}, board[index]), { candidates: board[index].value == null ? CANDIDATES.slice() : board[index].candidates }));
    };
    const strategies = [
      {
        postFn: updateCandidatesBasedOnCellsValue,
        title: "Open Singles Strategy",
        fn: openSinglesStrategy,
        score: 0.1,
        type: "value"
      },
      {
        postFn: updateCandidatesBasedOnCellsValue,
        title: "Visual Elimination Strategy",
        fn: visualEliminationStrategy,
        score: 9,
        type: "value"
      },
      {
        postFn: updateCandidatesBasedOnCellsValue,
        title: "Single Candidate Strategy",
        fn: singleCandidateStrategy,
        score: 8,
        type: "value"
      },
      {
        title: "Naked Pair Strategy",
        fn: nakedPairStrategy,
        score: 50,
        type: "elimination"
      },
      {
        title: "Pointing Elimination Strategy",
        fn: pointingEliminationStrategy,
        score: 80,
        type: "elimination"
      },
      {
        title: "Hidden Pair Strategy",
        fn: hiddenPairStrategy,
        score: 90,
        type: "elimination"
      }
      // {
      //   title: "Naked Triplet Strategy",
      //   fn: nakedTripletStrategy,
      //   score: 100,
      //   type: "elimination",
      // },
      // {
      //   title: "Hidden Triplet Strategy",
      //   fn: hiddenTripletStrategy,
      //   score: 140,
      //   type: "elimination",
      // },
      // {
      //   title: "Naked Quadruple Strategy",
      //   fn: nakedQuadrupleStrategy,
      //   score: 150,
      //   type: "elimination",
      // },
      // {
      //   title: "Hidden Quadruple Strategy",
      //   fn: hiddenQuadrupleStrategy,
      //   score: 280,
      //   type: "elimination",
      // },
    ];
    const initializeBoard = () => {
      const alreadyEnhanced = board[0] !== null && typeof board[0] === "object";
      if (!alreadyEnhanced) {
        board = Array.from({ length: BOARD_SIZE * BOARD_SIZE }, (_, index) => {
          var _a;
          const value = (_a = initBoard === null || initBoard === void 0 ? void 0 : initBoard[index]) !== null && _a !== void 0 ? _a : null;
          const candidates = value == null ? [...CANDIDATES] : [...NULL_CANDIDATE_LIST];
          return { value, candidates };
        });
      }
    };
    const removeCandidatesFromMultipleCells = (cells, candidates) => {
      const cellsUpdated = [];
      for (let i = 0; i < cells.length; i++) {
        const cellCandidates = board[cells[i]].candidates;
        for (let j = 0; j < candidates.length; j++) {
          const candidate = candidates[j];
          if (candidate && cellCandidates[candidate - 1] !== null) {
            cellCandidates[candidate - 1] = null;
            cellsUpdated.push({
              index: cells[i],
              eliminatedCandidate: candidate
            });
          }
        }
      }
      return cellsUpdated;
    };
    const housesWithCell = (cellIndex) => {
      const boxSideSize = Math.sqrt(BOARD_SIZE);
      const groupOfHouses = [];
      const horizontalRow = Math.floor(cellIndex / BOARD_SIZE);
      groupOfHouses.push(horizontalRow);
      const verticalRow = Math.floor(cellIndex % BOARD_SIZE);
      groupOfHouses.push(verticalRow);
      const box = Math.floor(horizontalRow / boxSideSize) * boxSideSize + Math.floor(verticalRow / boxSideSize);
      groupOfHouses.push(box);
      return groupOfHouses;
    };
    const getRemainingNumbers = (house) => {
      const usedNumbers = getUsedNumbers(house);
      return CANDIDATES.filter((candidate) => !usedNumbers.includes(candidate));
    };
    const getUsedNumbers = (house) => {
      return house.map((cellIndex) => board[cellIndex].value).filter(Boolean);
    };
    const getRemainingCandidates = (cellIndex) => {
      return board[cellIndex].candidates.filter((candidate) => candidate !== null);
    };
    const getPossibleCellsForCandidate = (candidate, house) => {
      return house.filter((cellIndex) => board[cellIndex].candidates.includes(candidate));
    };
    function openSinglesStrategy() {
      const groupOfHouses = GROUP_OF_HOUSES;
      for (let i = 0; i < groupOfHouses.length; i++) {
        for (let j = 0; j < BOARD_SIZE; j++) {
          const singleEmptyCell = findSingleEmptyCellInHouse(groupOfHouses[i][j]);
          if (singleEmptyCell) {
            return fillSingleEmptyCell(singleEmptyCell);
          }
          if (isBoardFinished(board)) {
            onFinish === null || onFinish === void 0 ? void 0 : onFinish(calculateBoardDifficulty(usedStrategies, strategies));
            return true;
          }
        }
      }
      return false;
    }
    function findSingleEmptyCellInHouse(house) {
      const emptyCells = [];
      for (let k = 0; k < BOARD_SIZE; k++) {
        const boardIndex = house[k];
        if (board[boardIndex].value == null) {
          emptyCells.push({ house, cellIndex: boardIndex });
          if (emptyCells.length > 1) {
            break;
          }
        }
      }
      return emptyCells.length === 1 ? emptyCells[0] : null;
    }
    function fillSingleEmptyCell(emptyCell) {
      const value = getRemainingNumbers(emptyCell.house);
      if (value.length > 1) {
        onError === null || onError === void 0 ? void 0 : onError({ message: "Board Incorrect" });
        return -1;
      }
      addValueToCellIndex(board, emptyCell.cellIndex, value[0]);
      return [{ index: emptyCell.cellIndex, filledValue: value[0] }];
    }
    function updateCandidatesBasedOnCellsValue() {
      const groupOfHousesLength = GROUP_OF_HOUSES.length;
      for (let houseType = 0; houseType < groupOfHousesLength; houseType++) {
        for (let houseIndex = 0; houseIndex < BOARD_SIZE; houseIndex++) {
          const house = GROUP_OF_HOUSES[houseType][houseIndex];
          const candidatesToRemove = getUsedNumbers(house);
          for (let cellIndex = 0; cellIndex < BOARD_SIZE; cellIndex++) {
            const cell = board[house[cellIndex]];
            cell.candidates = cell.candidates.filter((candidate) => !candidatesToRemove.includes(candidate));
          }
        }
      }
      return false;
    }
    const convertInitialBoardToSerializedBoard = (_board) => {
      return new Array(BOARD_SIZE * BOARD_SIZE).fill(null).map((_, i) => {
        const value = _board[i] || null;
        const candidates = value === null ? [...CANDIDATES] : [...NULL_CANDIDATE_LIST];
        return { value, candidates };
      });
    };
    function singleCandidateStrategy() {
      const groupOfHousesLength = GROUP_OF_HOUSES.length;
      for (let houseType = 0; houseType < groupOfHousesLength; houseType++) {
        for (let houseIndex = 0; houseIndex < BOARD_SIZE; houseIndex++) {
          const house = GROUP_OF_HOUSES[houseType][houseIndex];
          const digits = getRemainingNumbers(house);
          for (let digitIndex = 0; digitIndex < digits.length; digitIndex++) {
            const digit = digits[digitIndex];
            const possibleCells = [];
            for (let cellIndex = 0; cellIndex < BOARD_SIZE; cellIndex++) {
              const cell = house[cellIndex];
              const boardCell = board[cell];
              if (contains(boardCell.candidates, digit)) {
                possibleCells.push(cell);
                if (possibleCells.length > 1) {
                  break;
                }
              }
            }
            if (possibleCells.length === 1) {
              const cellIndex = possibleCells[0];
              addValueToCellIndex(board, cellIndex, digit);
              return [{ index: cellIndex, filledValue: digit }];
            }
          }
        }
      }
      return false;
    }
    function visualEliminationStrategy() {
      for (let cellIndex = 0; cellIndex < board.length; cellIndex++) {
        const cell = board[cellIndex];
        const candidates = cell.candidates;
        const possibleCandidates = [];
        for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
          if (candidates[candidateIndex] !== null) {
            possibleCandidates.push(candidates[candidateIndex]);
          }
          if (possibleCandidates.length > 1) {
            break;
          }
        }
        if (possibleCandidates.length === 1) {
          const digit = possibleCandidates[0];
          addValueToCellIndex(board, cellIndex, digit);
          return [{ index: cellIndex, filledValue: digit }];
        }
      }
      return false;
    }
    function pointingEliminationStrategy() {
      const groupOfHousesLength = GROUP_OF_HOUSES.length;
      for (let houseType = 0; houseType < groupOfHousesLength; houseType++) {
        for (let houseIndex = 0; houseIndex < BOARD_SIZE; houseIndex++) {
          const house = GROUP_OF_HOUSES[houseType][houseIndex];
          const digits = getRemainingNumbers(house);
          for (let digitIndex = 0; digitIndex < digits.length; digitIndex++) {
            const digit = digits[digitIndex];
            let sameAltHouse = true;
            let houseId = -1;
            let houseTwoId = -1;
            let sameAltTwoHouse = true;
            const cellsWithCandidate = [];
            for (let cellIndex = 0; cellIndex < house.length; cellIndex++) {
              const cell = house[cellIndex];
              if (contains(board[cell].candidates, digit)) {
                const cellHouses = housesWithCell(cell);
                const newHouseId = houseType === 2 ? cellHouses[0] : cellHouses[2];
                const newHouseTwoId = houseType === 2 ? cellHouses[1] : cellHouses[2];
                if (cellsWithCandidate.length > 0) {
                  if (newHouseId !== houseId) {
                    sameAltHouse = false;
                  }
                  if (houseTwoId !== newHouseTwoId) {
                    sameAltTwoHouse = false;
                  }
                  if (sameAltHouse === false && sameAltTwoHouse === false) {
                    break;
                  }
                }
                houseId = newHouseId;
                houseTwoId = newHouseTwoId;
                cellsWithCandidate.push(cell);
              }
            }
            if ((sameAltHouse || sameAltTwoHouse) && cellsWithCandidate.length > 0) {
              const altHouseType = houseType === 2 ? sameAltHouse ? 0 : 1 : 2;
              const altHouse = GROUP_OF_HOUSES[altHouseType][housesWithCell(cellsWithCandidate[0])[altHouseType]];
              const cellsEffected = [];
              for (let x = 0; x < altHouse.length; x++) {
                if (!cellsWithCandidate.includes(altHouse[x])) {
                  cellsEffected.push(altHouse[x]);
                }
              }
              const cellsUpdated = removeCandidatesFromMultipleCells(cellsEffected, [digit]);
              if (cellsUpdated.length > 0) {
                return cellsUpdated;
              }
            }
          }
        }
      }
      return false;
    }
    function nakedCandidatesStrategy(number) {
      let combineInfo = [];
      let minIndexes = [-1];
      const groupOfHousesLength = GROUP_OF_HOUSES.length;
      for (let i = 0; i < groupOfHousesLength; i++) {
        for (let j = 0; j < BOARD_SIZE; j++) {
          const house = GROUP_OF_HOUSES[i][j];
          if (getRemainingNumbers(house).length <= number) {
            continue;
          }
          combineInfo = [];
          minIndexes = [-1];
          const result = checkCombinedCandidates(house, 0);
          if (result !== false) {
            return result;
          }
        }
      }
      return false;
      function checkCombinedCandidates(house, startIndex) {
        for (let i = Math.max(startIndex, minIndexes[startIndex]); i < BOARD_SIZE - number + startIndex; i++) {
          minIndexes[startIndex] = i + 1;
          minIndexes[startIndex + 1] = i + 1;
          const cell = house[i];
          const cellCandidates = getRemainingCandidates(cell);
          if (cellCandidates.length === 0 || cellCandidates.length > number) {
            continue;
          }
          if (combineInfo.length > 0) {
            const temp = [...cellCandidates];
            for (let a = 0; a < combineInfo.length; a++) {
              const candidates = combineInfo[a].candidates || [];
              for (let b = 0; b < candidates.length; b++) {
                if (!temp.includes(candidates[b])) {
                  temp.push(candidates[b]);
                }
              }
            }
            if (temp.length > number) {
              continue;
            }
          }
          combineInfo.push({ cell, candidates: cellCandidates });
          if (startIndex < number - 1) {
            const result = checkCombinedCandidates(house, startIndex + 1);
            if (result !== false) {
              return result;
            }
          }
          if (combineInfo.length === number) {
            const cellsWithCandidates = [];
            let combinedCandidates = [];
            for (let x = 0; x < combineInfo.length; x++) {
              cellsWithCandidates.push(combineInfo[x].cell);
              combinedCandidates = combinedCandidates.concat(combineInfo[x].candidates || []);
            }
            const cellsEffected = house.filter((cell2) => !cellsWithCandidates.includes(cell2));
            const cellsUpdated = removeCandidatesFromMultipleCells(cellsEffected, combinedCandidates);
            if (cellsUpdated.length > 0) {
              return cellsUpdated;
            }
          }
        }
        if (startIndex > 0) {
          if (combineInfo.length > startIndex - 1) {
            combineInfo.pop();
          }
        }
        return false;
      }
    }
    function nakedPairStrategy() {
      return nakedCandidatesStrategy(2);
    }
    function hiddenLockedCandidates(number) {
      let combineInfo = [];
      let minIndexes = [-1];
      function checkLockedCandidates(house, startIndex) {
        for (let i = Math.max(startIndex, minIndexes[startIndex]); i <= BOARD_SIZE - number + startIndex; i++) {
          minIndexes[startIndex] = i + 1;
          minIndexes[startIndex + 1] = i + 1;
          const candidate = i + 1;
          const possibleCells = getPossibleCellsForCandidate(candidate, house);
          if (possibleCells.length === 0 || possibleCells.length > number)
            continue;
          if (combineInfo.length > 0) {
            const temp = possibleCells.slice();
            for (let a = 0; a < combineInfo.length; a++) {
              const cells = combineInfo[a].cells;
              for (let b = 0; b < cells.length; b++) {
                if (!contains(temp, cells[b]))
                  temp.push(cells[b]);
              }
            }
            if (temp.length > number) {
              continue;
            }
          }
          combineInfo.push({ candidate, cells: possibleCells });
          if (startIndex < number - 1) {
            const r = checkLockedCandidates(house, startIndex + 1);
            if (r !== false)
              return r;
          }
          if (combineInfo.length === number) {
            const combinedCandidates = [];
            let cellsWithCandidates = [];
            for (let x = 0; x < combineInfo.length; x++) {
              combinedCandidates.push(combineInfo[x].candidate);
              cellsWithCandidates = cellsWithCandidates.concat(combineInfo[x].cells);
            }
            const candidatesToRemove = [];
            for (let c = 0; c < BOARD_SIZE; c++) {
              if (!contains(combinedCandidates, c + 1))
                candidatesToRemove.push(c + 1);
            }
            const cellsUpdated = removeCandidatesFromMultipleCells(cellsWithCandidates, candidatesToRemove);
            if (cellsUpdated.length > 0) {
              return cellsUpdated;
            }
          }
        }
        if (startIndex > 0) {
          if (combineInfo.length > startIndex - 1) {
            combineInfo.pop();
          }
        }
        return false;
      }
      const groupOfHousesLength = GROUP_OF_HOUSES.length;
      for (let i = 0; i < groupOfHousesLength; i++) {
        for (let j = 0; j < BOARD_SIZE; j++) {
          const house = GROUP_OF_HOUSES[i][j];
          if (getRemainingNumbers(house).length <= number)
            continue;
          combineInfo = [];
          minIndexes = [-1];
          const result = checkLockedCandidates(house, 0);
          if (result !== false)
            return result;
        }
      }
      return false;
    }
    function hiddenPairStrategy() {
      return hiddenLockedCandidates(2);
    }
    const applySolvingStrategies = ({ strategyIndex = 0, analyzeMode = false } = {}) => {
      var _a, _b;
      if (isBoardFinished(board)) {
        if (!analyzeMode) {
          onFinish === null || onFinish === void 0 ? void 0 : onFinish(calculateBoardDifficulty(usedStrategies, strategies));
        }
        return false;
      }
      const effectedCells = strategies[strategyIndex].fn();
      (_b = (_a = strategies[strategyIndex]).postFn) === null || _b === void 0 ? void 0 : _b.call(_a);
      if (effectedCells === false) {
        if (strategies.length > strategyIndex + 1) {
          return applySolvingStrategies({
            strategyIndex: strategyIndex + 1,
            analyzeMode
          });
        } else {
          onError === null || onError === void 0 ? void 0 : onError({ message: "No More Strategies To Solve The Board" });
          return false;
        }
      }
      if (effectedCells === -1) {
        return false;
      }
      if (!analyzeMode) {
        onUpdate === null || onUpdate === void 0 ? void 0 : onUpdate({
          strategy: strategies[strategyIndex].title,
          updates: effectedCells,
          type: strategies[strategyIndex].type
        });
      }
      if (typeof usedStrategies[strategyIndex] === "undefined") {
        usedStrategies[strategyIndex] = 0;
      }
      usedStrategies[strategyIndex] += 1;
      return strategies[strategyIndex].type;
    };
    const setBoardCellWithRandomCandidate = (cellIndex) => {
      updateCandidatesBasedOnCellsValue();
      const invalids = board[cellIndex].invalidCandidates || [];
      const candidates = board[cellIndex].candidates.filter((candidate) => Boolean(candidate) && !invalids.includes(candidate));
      if (candidates.length === 0) {
        return false;
      }
      const value = getRandomCandidateOfCell(candidates);
      addValueToCellIndex(board, cellIndex, value);
      return true;
    };
    const invalidPreviousCandidateAndStartOver = (cellIndex) => {
      var _a;
      const previousIndex = cellIndex - 1;
      board[previousIndex].invalidCandidates = board[previousIndex].invalidCandidates || [];
      (_a = board[previousIndex].invalidCandidates) === null || _a === void 0 ? void 0 : _a.push(board[previousIndex].value);
      addValueToCellIndex(board, previousIndex, null);
      resetCandidates();
      board[cellIndex].invalidCandidates = [];
      generateBoardAnswerRecursively(previousIndex);
    };
    const generateBoardAnswerRecursively = (cellIndex) => {
      if (cellIndex + 1 > BOARD_SIZE * BOARD_SIZE) {
        board.forEach((cell) => cell.invalidCandidates = []);
        return true;
      }
      if (setBoardCellWithRandomCandidate(cellIndex)) {
        generateBoardAnswerRecursively(cellIndex + 1);
      } else {
        invalidPreviousCandidateAndStartOver(cellIndex);
      }
    };
    function isValidAndEasyEnough(analysis, difficulty2) {
      return analysis.hasSolution && analysis.difficulty && isEasyEnough(difficulty2, analysis.difficulty);
    }
    const prepareGameBoard = () => {
      const cells = Array.from({ length: BOARD_SIZE * BOARD_SIZE }, (_, i) => i);
      let removalCount = getRemovalCountBasedOnDifficulty(difficulty);
      while (removalCount > 0 && cells.length > 0) {
        const randIndex = Math.floor(Math.random() * cells.length);
        const cellIndex = cells.splice(randIndex, 1)[0];
        const cellValue = board[cellIndex].value;
        addValueToCellIndex(board, cellIndex, null);
        resetCandidates();
        const boardAnalysis = analyzeBoard();
        if (isValidAndEasyEnough(boardAnalysis, difficulty) && isUniqueSolution(getBoard())) {
          removalCount--;
        } else {
          addValueToCellIndex(board, cellIndex, cellValue);
        }
      }
    };
    function filterAndMapStrategies(strategies2, usedStrategies2) {
      return strategies2.map((strategy, i) => usedStrategies2[i] !== void 0 ? { title: strategy.title, freq: usedStrategies2[i] } : null).filter(Boolean);
    }
    function analyzeBoard() {
      let usedStrategiesClone = usedStrategies.slice();
      let boardClone = JSON.parse(JSON.stringify(board));
      let Continue = true;
      while (Continue) {
        Continue = applySolvingStrategies({
          strategyIndex: Continue === "elimination" ? 1 : 0,
          analyzeMode: true
        });
      }
      const data = {
        hasSolution: isBoardFinished(board),
        usedStrategies: filterAndMapStrategies(strategies, usedStrategies)
      };
      if (data.hasSolution) {
        const boardDiff = calculateBoardDifficulty(usedStrategies, strategies);
        data.difficulty = boardDiff.difficulty;
        data.score = boardDiff.score;
      }
      usedStrategies = usedStrategiesClone.slice();
      board = boardClone;
      usedStrategiesClone = usedStrategies.slice();
      boardClone = JSON.parse(JSON.stringify(board));
      let solvedBoard = [...getBoard()];
      while (solvedBoard && !solvedBoard.every(Boolean)) {
        solvedBoard = solveStep({ analyzeMode: true, iterationCount: 0 });
      }
      usedStrategies = usedStrategiesClone.slice();
      board = boardClone;
      return data;
    }
    function generateBoard() {
      generateBoardAnswerRecursively(0);
      const slicedBoard = JSON.parse(JSON.stringify(board));
      function isBoardTooEasy() {
        prepareGameBoard();
        const data = analyzeBoard();
        if (data.hasSolution && data.difficulty) {
          return !isHardEnough(difficulty, data.difficulty);
        }
        return true;
      }
      function restoreBoardAnswer() {
        board = slicedBoard.slice();
      }
      while (isBoardTooEasy()) {
        restoreBoardAnswer();
      }
      updateCandidatesBasedOnCellsValue();
      return getBoard();
    }
    const MAX_ITERATIONS = 30;
    const solveStep = ({ analyzeMode = false, iterationCount = 0 } = {}) => {
      if (iterationCount >= MAX_ITERATIONS) {
        return false;
      }
      const initialBoard = getBoard().slice();
      applySolvingStrategies({ analyzeMode });
      const stepSolvedBoard = getBoard().slice();
      const boardNotChanged = initialBoard.filter(Boolean).length === stepSolvedBoard.filter(Boolean).length;
      if (!isBoardFinished(board) && boardNotChanged) {
        return solveStep({ analyzeMode, iterationCount: iterationCount + 1 });
      }
      board = convertInitialBoardToSerializedBoard(stepSolvedBoard);
      updateCandidatesBasedOnCellsValue();
      return getBoard();
    };
    const solveAll = () => {
      let Continue = true;
      while (Continue) {
        Continue = applySolvingStrategies({
          strategyIndex: Continue === "elimination" ? 1 : 0
        });
      }
      return getBoard();
    };
    const getBoard = () => board.map((cell) => cell.value);
    if (!initBoard) {
      initializeBoard();
      generateBoard();
    } else {
      board = convertInitialBoardToSerializedBoard(initBoard);
      updateCandidatesBasedOnCellsValue();
      analyzeBoard();
    }
    return {
      solveAll,
      solveStep,
      analyzeBoard,
      getBoard,
      generateBoard
    };
  }

  // ../../../../private/tmp/sudoku-core-inspect/package/dist/esm/index.js
  function analyze(Board) {
    const { analyzeBoard } = createSudokuInstance({
      initBoard: Board.slice()
    });
    return Object.assign(Object.assign({}, analyzeBoard()), { hasUniqueSolution: isUniqueSolution(Board) });
  }
  function generate(difficulty) {
    const { getBoard } = createSudokuInstance({ difficulty });
    if (!analyze(getBoard()).hasUniqueSolution) {
      return generate(difficulty);
    }
    return getBoard();
  }
  function solve(Board) {
    const solvingSteps = [];
    const { solveAll } = createSudokuInstance({
      initBoard: Board.slice(),
      onUpdate: (solvingStep) => solvingSteps.push(solvingStep)
    });
    const analysis = analyze(Board);
    if (!analysis.hasSolution) {
      return { solved: false, error: "No solution for provided board!" };
    }
    const board = solveAll();
    if (!analysis.hasUniqueSolution) {
      return {
        solved: true,
        board,
        steps: solvingSteps,
        analysis,
        error: "No unique solution for provided board!"
      };
    }
    return { solved: true, board, steps: solvingSteps, analysis };
  }
  function hint(Board) {
    const solvingSteps = [];
    const { solveStep } = createSudokuInstance({
      initBoard: Board.slice(),
      onUpdate: (solvingStep) => solvingSteps.push(solvingStep)
    });
    const analysis = analyze(Board);
    if (!analysis.hasSolution) {
      return { solved: false, error: "No solution for provided board!" };
    }
    const board = solveStep();
    if (!board) {
      return { solved: false, error: "No solution for provided board!" };
    }
    if (!analysis.hasUniqueSolution) {
      return {
        solved: true,
        board,
        steps: solvingSteps,
        analysis,
        error: "No unique solution for provided board!"
      };
    }
    return { solved: true, board, steps: solvingSteps, analysis };
  }
  return __toCommonJS(esm_exports);
})();
