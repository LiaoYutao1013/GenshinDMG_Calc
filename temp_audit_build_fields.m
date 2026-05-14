addpath(genpath(pwd)); initProjectPaths;
chars = {'Skirk','Escoffier','Arlecchino','Furina','Chasca','Lauma','Ineffa','Linnea','Nilou','Nefer','Flins','Zibai','Mualani','Mavuika','Citlali','Xilonen','Neuvillette','Chevreuse','Iansan','Varesa','Durin','Nicole'};
for i = 1:numel(chars)
 cfg = getDefaultCharacterConfig(chars{i});
 disp(['=== ' chars{i} ' ===']);
 disp(fieldnames(cfg.Build));
end
exit
