import TOML

function registered_trees(registry_path)
    trees = Dict{String, Vector{@NamedTuple{name::String, version::String, tree::String}}}()
    for pkg in values(TOML.parsefile(joinpath(registry_path, "Registry.toml"))["packages"])
        dir = joinpath(registry_path, pkg["path"])
        repo = TOML.parsefile(joinpath(dir, "Package.toml"))["repo"]
        for (version, entry) in TOML.parsefile(joinpath(dir, "Versions.toml"))
            push!(get!(trees, repo, []), (; name = pkg["name"], version, tree = entry["git-tree-sha1"]))
        end
    end
    return trees
end

# A full clone of the default branch only: a partial clone would lazy-fetch a
# missing tree, and GitHub serves objects reachable only from PR refs.
function missing_trees(repo, entries)
    return mktempdir() do clone
        run(`git clone --quiet --bare --single-branch $repo $clone`)
        filter(e -> !success(`git -C $clone cat-file -e $(e.tree)^\{tree\}`), entries)
    end
end

function main(registry_path)
    missing = 0
    for (repo, entries) in registered_trees(registry_path), e in missing_trees(repo, entries)
        println("$(e.name) v$(e.version): tree $(e.tree) is not on the default branch of $repo")
        missing += 1
    end
    return missing == 0
end

main(pwd()) || exit(1)
