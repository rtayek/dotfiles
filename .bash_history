direnv allow
cd dotfiles
cd direnv/
cd ..
ls -a
cp .envrc ~/eclipse-workspace/
cp .envrc /c/dfromrays8350/ray/allEclipseProjects/
cp .envrc /c/dfromrays8350/ray/conradapps/
cd dotfiles
git remote -v
git remote add origin https://github.com/rtayek/dotfiles.git
git branch -M master
git push -u origin master
gs
mkdir git
cd git
start pspad gitignore
start pspad gitignoregit config --global core.excludesfile ~/dotfiles/git/gitignore
gs
gd
cd ..
cat bash/bashrc 
cd dotfiles
gs
