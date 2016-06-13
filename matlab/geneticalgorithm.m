%AUTHOR: MOHAMMAD M. GHASSEMI
%EMAIL: ghassemi@mit.edu

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% NON LINEAR STUFF
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all;
load('Heparin_05_21_13.mat') 


%% To begin with, we constrained our data to include only those non-null entries
%QUESTION: DO WE WANT TO ADD ANY MORE FEATURES!!!
index = (CREATININBEFORE >= 0).*...
        (AGE >= 0).*...
        (GENDER >= 0).*...
        (SOFAADJUSTED >= 0).*...
        (ELIXHAUSERPT >= 0).*...
        (TRANSFERFLAG >= 0).*...
        (ICUSTAYGROUPCSRUSICU >=0).*...
        (DOSEBYWEIGHT >= 0).*...
        (PTT6HRTIMEFROMHEP >= 0).*...
        (ETHNICITYDESCR >= 0).*...
        (NUMHEPEVENTS >= 0);
index = find(index ==1)

%% THE OUTCOMES
y = PTTVAL6HR(index)

x_label = {'CREATININBEFORE',...
      'AGE',...
      'GENDER',...
      'SOFAADJUSTED',...
      'ELIXHAUSERPT',...
      'ICUSTAYGROUPCSRUSICU',... %1 is MICU
      'DOSEBYWEIGHT',...
      'PTT6HRTIMEFROMHEP',...
      'ETHNICITYDESCR',...
      'NUMHEPEVENTS'}; %1 is white

%THE INPUT VARIABLES
x = [ CREATININBEFORE(index),...
      AGE(index),...
      GENDER(index),...
      SOFAADJUSTED(index),...
      ELIXHAUSERPT(index),...
      ICUSTAYGROUPCSRUSICU(index),... %1 is MICU
      DOSEBYWEIGHT(index),...
      PTT6HRTIMEFROMHEP(index),...
      ETHNICITYDESCR(index),... %0 is white
      NUMHEPEVENTS(index)]; 

%% FIND THE BINARY VARIABLES  
binary_vars = [];
for(i=1:size(x,2))
    if(sum(unique(x(:,i))) == 1)
        binary_vars = [binary_vars, i];
    end
end
%FIND THE CONTINUOUS VARIABLES
continuous_vars = setdiff([1:size(x,2)],binary_vars);
%% Figure out which features should be log transformed.
%To do this, we used the Lillie test for normality on each of the features 
%both before and after a log transform. Note that we added +1 to the data to prevent the logarithm from
% Exploding. If the distribution of feature data was more normal after the log transformation than before, we transformed
%the features into log form.
%QUESTION: WHY DO WE WANT NORMALLY DISTRIBUTED VARIABLES?!

%Check for normal
for i=1:size(x,2)
   [h,p1(i),kstat1(i)] = lillietest(x(:,i))
end

%check for log normal
for i=1:size(x,2)
    [h,p2(i),kstat2(i)] = lillietest(log(x(:,i)+1));
end

vars_needing_log_transform = intersect(find(kstat2 < kstat1),continuous_vars);

%% Log transform the variables that take a more normal form when log transformed.
for i=vars_needing_log_transform
   x(:,i) = log(x(:,i)+1); 
end

%% Normalize all the continuous variables to mean 0 and unit variace
y = (y - mean(y))/std(y);                            %The output
for i=continuous_vars
   x(:,i) =(x(:,i) - mean(x(:,i)))/std(x(:,i));      %The input
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% GENETIC ALGORITHM
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clearvars -except x y

%%CHANGE THE X and Y Vars so that the data is positive
x = x +10;
y = y +10;

%NEWTONIAN INITAL GUESS OPTIMIZATION:
num_points_to_test = 50; 
lower_bound = -10;
upper_bound = 10;
ms = MultiStart;
ms.UseParallel = 'always';
ms.Display = 'off';


%INPUT PARAMETERS
%General form of the model is b1*x1^k1 + ... + bn*xn^kn 
num_params = 2*size(x,2) + 1;                  %The number of features
num_models = 500;                             %The number of models in the population
num_generations = 50;                          %The number of generations you want for the models
mutation_rate = .01;                           %some number between 0 and 1 where 0 means no mutations next gen, and 1 means will completely mutate.

sexual = 1;                                     %denotes sexual reproduction.            
top_perc = 0.1;                                 %What top % survive 
dominent_gene_strength = .5;

opts = statset('TolFun',1e-8,'MaxIter',100);    %The tolerance for convergence of the non-linear solver, and the %Max-Iterations
warning off;

matlabpool open;
pctRunOnAll warning off;
for k = 1:num_generations
    
    %In the first iteration- we will need to create a random population
    if(k == 1)
        genes = randi(2,num_params,num_models)-1;                      %create <num_models> genomes, <num_params> in length
        genes(:,1) = [1 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]';     %Ensure that the linear model is one of the models we are looking at.
    end
    %gene2model(x,genes(:,1))
    
    
    %EVALUATE THE GENOME MODELS
    tic
    clear lse
    parfor i = 1:num_models                                            %Generate the models
        [models{i}, bval(i)] = gene2model(x,genes(:,i));                   %calling the gene2modelfunction
        try
            i
            %THIS WILL DO A NON-LINEAR SOLVE FOR THE BEST PARAMETERS AND
            %SPIT OUT A 2 FOLD CROSS VALIDATION MSE
            [lse(i)] = evalModel(x,y,bval(i),opts,models{i}, i,num_points_to_test,upper_bound,lower_bound,ms);           %evaluate the models
        catch
            %If y the model screws
            lse(i)= Inf;
            'bad apple'
        end
    end
    toc

    
    %NOW THAT WE HAVE GENERATED SOME MODELS, WE JUDGE THEIR FITNESS USING
    %LSE OF THE FIT ON THE NOVEL DATA.
    [sorted_lse ranked_genes] = sort(lse,'ascend');
    
    %FOR THE ASEXUAL POPULATION - EXTRACT THE TOP 10%
    
    %if(sexual == 0)
    %    best_genes = (:,ranked_genes(1:(num_models*.1)));
    %    new_genes = best_genes;
    %    %Take some mutations as well.
    %    for i= 1:9
    %        mutations = rand(size(best_genes,1),size(best_genes,2)) < mutation_rate;
    %        new_genes = [new_genes,xor(best_genes,mutations)];
    %    end
    %end
    
    %no dominent or recessive tradeoff
    clear best_genes;
    if(sexual == 1)
        best_genes = genes(:,ranked_genes(1:(num_models*top_perc)));
        new_genes = repmat(best_genes,1,1/top_perc);
        
        %everyone get's to breed - they are called moms
        moms = new_genes;
        %Who they choose to breed with are the dads. Like human mating, the
        %males are at a distinct disadvantage.
        dads = new_genes(:,randi(size(new_genes,2),1,size(new_genes,2)));

        %Dominent and recessive traits
        dominent_traits = dads.*moms;
        recessive_traits = abs(dads-moms).*((rand(size(dominent_traits,1),size(dominent_traits,2)))<=dominent_gene_strength);
        
        new_genes = dominent_traits + recessive_traits;
        
        %Take some mutations as well.
        mutations = rand(size(new_genes,1),size(new_genes,2)) < mutation_rate;
        new_genes(mutations) = not(new_genes(mutations));
    end
    
    %Now update this generations genes
    genes = new_genes;
    genes(:,1) = [1 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0]';
    
    %Record the best rsquared from this generation
    best_lse(k) = sorted_lse(1);
    winning_genes(:,k) = genes(:,ranked_genes(1));
    save best_lse best_lse
    save winning_genes winning_genes
    
    hold on;
    plot(k,best_lse(k),'.')
    
end
matlabpool close;




%% NOW LET'S LOOK AT THE WINNING GENES AND RUN AN OPTIMIZER ON THEM TO SEE HOW THEY DO.
clearvars -except x y
x = x+10; y = y+10;
load winning_genes;

winning_genes = winning_genes(:,48)
winning_model = gene2model(x,winning_genes)

ms = MultiStart
ms.UseParallel = 'always';

num_points_to_test = 10000                   
ms = MultiStart
ms.UseParallel = 'always';

model = winning_model;

Indices = crossvalind('Kfold', size(y,1), 10);           %Generate the indicies
for(i=1:10)
    num2str(i*10)
    testing_ind = Indices == i;                          %testing indicies  (10%)
    training_ind = not(testing_ind);                     %training indicies (90%)
    
    %SET UP THE PROBLEM    
    problem = createOptimProblem('lsqcurvefit',...
                             'objective', model,...
                             'xdata',x(training_ind,:),...
                             'ydata',y(training_ind),...
                             'x0',ones(1,11),...
                             'lb',-50*ones(1,11),...
                             'ub',50*ones(1,11))   
    
    %Evaluate the function at many initial Guesses, and take the coefficients that fit best 
    [b,fval,exitflag,output,solutions] = run(ms,problem,num_points_to_test);
    coefficients(:,i) = b;
    save coefficients coefficients
    %!! MAYBE YOU SHOULD REMOVE THE COOKS D OUTLIERS 
    
    %least_square_error of the model on the testing data.
    lse(i) = sum((model(b,x(testing_ind,:)) - y(testing_ind)).^2);
    save lse lse
end

X = coefficients';

%And we stepped up the number of components in the kmeans calssifer until 2
%of the means came close. We set the number of replicates to 10, and chose
%the one with the best total sum of distances.

%!! SHOW A PROJECTION FROM THE 11 DIMENTIONAL SPACE INTO A 2 DIMENTIONAL
%SPACE.
opts = statset('Display','final');
[idx,ctrs] = kmeans(X,2,...
                    'distance','sqEuclidean',...
                    'Replicates',10,...
                    'Options',opts);

%Let's generate the predictions for each of the models 
model_1_predictions = model(ctrs(1,:), x);
[m1_r2 m1_rmse] = rsquare(y,model_1_predictions)
model_2_predictions = model(ctrs(2,:), x);
[M2_r2 m2_rmse] = rsquare(y,model_2_predictions)

for i= 1:10
coefficients(:,i)
    predictions = model(coefficients(:,i),x);
plot(y,predictions,'.')
hold on;
plot([8 12],[8 12],'--r')
waitforbuttonpress

end

[r2 rmse] = rsquare(y,predictions)


                                  