export SCIPSolver

# Model

type SCIPMathProgModel <: AbstractLinearQuadraticModel
    ptr_model::Ptr{Void}

    function SCIPMathProgModel()
        _arr = Array(Ptr{Void}, 1)
        # TODO: check return code (everywhere!)
        ccall((:CSIPcreateModel, csip), Cint, (Ptr{Ptr{Void}}, ), _arr)
        new(_arr[1])

        # QUESTION: Why is _arr not garbage-collected?
    end
end

# Solver

immutable SCIPSolver <: AbstractMathProgSolver
end
LinearQuadraticModel(s::SCIPSolver) = SCIPMathProgModel()

# Interface

function loadproblem!(m::SCIPMathProgModel, A, varlb, varub, obj, rowlb, rowub, sense)
    # TODO: clean old model?

    nrows, ncols = size(A)
    nvars = Cint(ncols)
    varindices = collect(zero(Cint):nvars - one(Cint))

    for v in 1:ncols
        # TODO: define enum for vartype?
        _addVar(m.ptr_model, float(varlb[v]), float(varub[v]),
                Cint(3), Ptr{Cint}(C_NULL))
    end
    for c in 1:nrows
        # TODO: care about sparse matrices
        denserow = float(collect(A[c, :]))
        _addLinCons(m.ptr_model, nvars, varindices, denserow,
                    float(rowlb[c]), float(rowub[c]), Ptr{Cint}(C_NULL))
    end

    _setObj(m.ptr_model, nvars, varindices, float(obj))

    # TODO: set sense
end

# TODO: mapping for :SemiCont, :SemiInt
const vartypemap = Dict{Symbol, Cint}(
  :Cont => 3,
  :Bin => 0,
  :Int => 1
)

function setvartype!(m::SCIPMathProgModel, vartype::Vector{Symbol})
    nvars = Cint(length(vartype))
    scipvartypes = map(vt -> vartypemap[vt], vartype)
    for idx = one(Cint):nvars
        _chgVarType(m.ptr_model, idx - one(Cint), scipvartypes[idx])
    end
end

optimize!(m::SCIPMathProgModel) = _solve(m.ptr_model)

function status(m::SCIPMathProgModel)
    statusmap = [:Optimal,
                 :Infeasible,
                 :Unbounded,
                 :InfeasibleOrUnbounded,
                 :UserLimit, # node limit
                 :UserLimit, # time limit
                 :UserLimit, # memory limit
                 :UserLimit, # user limit
                 :Unknown    # TODO: find good value
                 ]
    stat = _getStatus(m.ptr_model)
    return statusmap[stat + 1]
end

function getobjval(m::SCIPMathProgModel)
    _getObjValue(m.ptr_model)
end

function getsolution(m::SCIPMathProgModel)
    nvars = _getNumVars(m.ptr_model)
    values = zeros(nvars)
    _getVarValues(m.ptr_model, values)
    values
end

# Not supported by SCIP or CSIP, but expected from MPB
# TODO: print warning when called?
# TODO: should we just support `mixintprog` but not `linprog`?

getreducedcosts(m::SCIPMathProgModel) = nothing
getconstrduals(m::SCIPMathProgModel) = nothing
getinfeasibilityray(m::SCIPMathProgModel) = nothing
getunboundedray(m::SCIPMathProgModel) = nothing